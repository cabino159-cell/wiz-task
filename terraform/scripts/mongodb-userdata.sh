#!/bin/bash
set -e

# MongoDB User Data Script
# This script installs and configures MongoDB on Ubuntu (intentionally outdated version)

echo "Starting MongoDB installation..."

# Update system packages
apt-get update -y

# Install dependencies
apt-get install -y \
    curl \
    gnupg \
    software-properties-common \
    awscli \
    jq

# Install MongoDB ${mongodb_version} (intentionally outdated)
curl -fsSL https://www.mongodb.org/static/pgp/server-${mongodb_version}.asc | apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/${mongodb_version} multiverse" | tee /etc/apt/sources.list.d/mongodb-org-${mongodb_version}.list

apt-get update -y
apt-get install -y mongodb-org=${mongodb_version}.*

# Start and enable MongoDB
systemctl start mongod
systemctl enable mongod

# Configure MongoDB to allow remote connections
sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/g' /etc/mongod.conf

# Enable authentication
cat >> /etc/mongod.conf <<EOF

security:
  authorization: enabled
EOF

# Restart MongoDB to apply changes
systemctl restart mongod

# Wait for MongoDB to start
sleep 10

# Create admin user
mongosh admin --eval '
db.createUser({
  user: "admin",
  pwd: "TaskyAdmin123!",
  roles: [ { role: "root", db: "admin" } ]
})
'

# Create application database and user
mongosh admin -u admin -p TaskyAdmin123! --eval '
use tasky
db.createUser({
  user: "taskyapp",
  pwd: "TaskyApp123!",
  roles: [ { role: "readWrite", db: "tasky" } ]
})
'

# Create backup script
cat > /usr/local/bin/mongodb-backup.sh <<'BACKUP_SCRIPT'
#!/bin/bash
set -e

BACKUP_DIR="/tmp/mongodb-backup"
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H-%M-%S)
BACKUP_NAME="mongodb-backup-$DATE-$TIME"
S3_BUCKET="${backup_bucket}"
AWS_REGION="${aws_region}"

# Create backup directory
mkdir -p $BACKUP_DIR

# Run mongodump
mongodump --host localhost --port 27017 \
  -u admin -p TaskyAdmin123! \
  --authenticationDatabase admin \
  --out $BACKUP_DIR/$BACKUP_NAME

# Compress backup
cd $BACKUP_DIR
tar -czf $BACKUP_NAME.tar.gz $BACKUP_NAME

# Upload to S3
aws s3 cp $BACKUP_NAME.tar.gz s3://$S3_BUCKET/backups/$DATE/$BACKUP_NAME.tar.gz \
  --region $AWS_REGION

# Clean up local backup
rm -rf $BACKUP_DIR/$BACKUP_NAME
rm -f $BACKUP_DIR/$BACKUP_NAME.tar.gz

echo "Backup completed: $BACKUP_NAME.tar.gz uploaded to s3://$S3_BUCKET/backups/$DATE/"
BACKUP_SCRIPT

chmod +x /usr/local/bin/mongodb-backup.sh

# Set up cron job for daily backups at 2 AM
cat > /etc/cron.d/mongodb-backup <<EOF
0 2 * * * root /usr/local/bin/mongodb-backup.sh >> /var/log/mongodb-backup.log 2>&1
EOF

# Run initial backup
/usr/local/bin/mongodb-backup.sh

# Create health check script
cat > /usr/local/bin/mongodb-health.sh <<'HEALTH_SCRIPT'
#!/bin/bash
mongosh admin -u admin -p TaskyAdmin123! --eval "db.serverStatus()" --quiet > /dev/null
if [ $? -eq 0 ]; then
  echo "MongoDB is healthy"
  exit 0
else
  echo "MongoDB is unhealthy"
  exit 1
fi
HEALTH_SCRIPT

chmod +x /usr/local/bin/mongodb-health.sh

# Install CloudWatch agent (optional)
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb

# Create CloudWatch config
cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json <<EOF
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/mongodb/mongod.log",
            "log_group_name": "/aws/ec2/mongodb",
            "log_stream_name": "{instance_id}/mongod.log"
          },
          {
            "file_path": "/var/log/mongodb-backup.log",
            "log_group_name": "/aws/ec2/mongodb",
            "log_stream_name": "{instance_id}/backup.log"
          }
        ]
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json

echo "MongoDB installation and configuration completed!"
echo "MongoDB Admin User: admin"
echo "MongoDB Admin Password: TaskyAdmin123!"
echo "MongoDB App User: taskyapp"
echo "MongoDB App Password: TaskyApp123!"
echo "Connection String: mongodb://taskyapp:TaskyApp123!@$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4):27017/tasky?authSource=tasky"

# Save connection info to file
cat > /root/mongodb-connection-info.txt <<EOF
MongoDB Connection Information
==============================
Host: $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
Port: 27017
Database: tasky

Admin User: admin
Admin Password: TaskyAdmin123!

App User: taskyapp
App Password: TaskyApp123!

Connection String:
mongodb://taskyapp:TaskyApp123!@$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4):27017/tasky?authSource=tasky

Backup Bucket: ${backup_bucket}
Backup Schedule: Daily at 2 AM UTC
EOF

chmod 600 /root/mongodb-connection-info.txt

echo "Setup complete! Connection info saved to /root/mongodb-connection-info.txt"
