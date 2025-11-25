# Terraform Infrastructure - Wiz Technical Exercise

This directory contains Terraform code to deploy the complete infrastructure for the Wiz Technical Exercise v4.

## Architecture

- **VPC**: Custom VPC with public and private subnets across 3 AZs
- **EKS Cluster**: Kubernetes cluster in private subnets
- **MongoDB EC2**: EC2 instance with MongoDB in public subnet (intentionally misconfigured)
- **S3 Buckets**: Backup bucket (public-readable) and Terraform state bucket
- **Security**: IAM roles, security groups, and OIDC provider

## Intentional Security Misconfigurations

The following misconfigurations are **intentional** for the exercise:

### MongoDB EC2 Instance
- ✗ SSH exposed to 0.0.0.0/0
- ✗ Outdated Ubuntu OS (1+ year old)
- ✗ Outdated MongoDB version 4.4
- ✗ IAM role can create EC2 instances
- ✗ Unencrypted root volume

### S3 Backup Bucket
- ✗ Public read and list access
- ✗ No server-side encryption

## Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** v1.6.0 or later
3. **SSH Key Pair** for MongoDB access

### Generate SSH Key

```bash
mkdir -p ssh-keys
ssh-keygen -t rsa -b 4096 -f ssh-keys/mongodb-key -N ""
```

## File Structure

```
terraform/
├── main.tf              # Provider and backend configuration
├── variables.tf         # Input variables
├── outputs.tf           # Output values
├── vpc.tf               # VPC, subnets, routing
├── eks.tf               # EKS cluster and node groups
├── mongodb.tf           # MongoDB EC2 instance
├── s3.tf                # S3 buckets for backups and state
├── scripts/
│   └── mongodb-userdata.sh  # MongoDB installation script
└── ssh-keys/
    └── mongodb-key.pub  # SSH public key (you generate this)
```

## Deployment

### Step 1: Initialize Terraform

```bash
cd terraform
terraform init
```

### Step 2: Review Variables

Edit `terraform.tfvars` or pass variables:

```hcl
aws_region     = "us-east-1"
environment    = "production"
owner_email    = "your-email@example.com"
mongodb_uri    = "mongodb://taskyapp:TaskyApp123!@<will-be-generated>:27017/tasky?authSource=tasky"
secret_key     = "generate-with-openssl-rand-hex-32"
```

### Step 3: Plan

```bash
terraform plan -out=tfplan
```

### Step 4: Apply

```bash
terraform apply tfplan
```

Deployment takes approximately 15-20 minutes.

### Step 5: Get Outputs

```bash
terraform output
terraform output -json > outputs.json
```

## Important Outputs

After deployment, you'll get:

- **EKS Cluster Name**: For kubectl configuration
- **MongoDB Connection String**: For application configuration
- **MongoDB SSH Command**: To access the instance
- **Backup Bucket Name**: For validation
- **Next Steps**: Detailed instructions

## Configure kubectl

```bash
aws eks update-kubeconfig --name <cluster-name> --region <region>
kubectl get nodes
```

## Access MongoDB

```bash
ssh -i ssh-keys/mongodb-key ubuntu@<public-ip>

# Check MongoDB status
sudo systemctl status mongod

# View connection info
sudo cat /root/mongodb-connection-info.txt

# Check backup logs
sudo cat /var/log/mongodb-backup.log
```

## Verify Backups

```bash
# List backups in S3
aws s3 ls s3://<backup-bucket-name>/backups/

# Test public access (should work - intentional misconfiguration)
curl https://<backup-bucket-name>.s3.amazonaws.com/
```

## Update Configuration

To modify the infrastructure:

1. Edit the `.tf` files
2. Run `terraform plan` to review changes
3. Run `terraform apply` to apply changes

## Terraform State Backend (Optional)

After first deployment, migrate to remote state:

1. Get the state bucket name from outputs:
   ```bash
   terraform output terraform_state_bucket
   ```

2. Uncomment the backend configuration in `main.tf`:
   ```hcl
   backend "s3" {
     bucket         = "<your-state-bucket>"
     key            = "tasky/terraform.tfstate"
     region         = "us-east-1"
     encrypt        = true
     dynamodb_table = "<your-lock-table>"
   }
   ```

3. Migrate the state:
   ```bash
   terraform init -migrate-state
   ```

## Destroy Infrastructure

To tear down all resources:

```bash
terraform destroy
```

**Warning**: This will delete:
- EKS cluster and all Kubernetes resources
- MongoDB EC2 instance and all data
- S3 buckets (if empty)
- VPC and all networking

## Cost Estimation

Approximate monthly costs (us-east-1):
- EKS Cluster: ~$73/month
- EKS Node Groups (3x t3.medium): ~$75/month
- MongoDB EC2 (t3.medium): ~$30/month
- NAT Gateways (3): ~$100/month
- S3 Storage: <$5/month
- Data Transfer: Variable

**Total**: ~$283/month

To reduce costs:
- Use 1 NAT Gateway instead of 3
- Use smaller instance types
- Use Spot instances for node groups

## Troubleshooting

### EKS Cluster Creation Fails
- Check IAM permissions
- Verify subnet configuration
- Check AWS service quotas

### MongoDB Installation Fails
- SSH to instance: Check `/var/log/cloud-init-output.log`
- Verify user data script executed
- Check security group allows access

### Cannot Connect to MongoDB
- Verify security group rules
- Check MongoDB is running: `sudo systemctl status mongod`
- Test from EKS: `kubectl run -it --rm debug --image=mongo:4.4 --restart=Never -- mongosh <connection-string>`

### Backups Not Working
- Check IAM role permissions
- Verify cron job: `sudo crontab -l`
- Check backup logs: `sudo cat /var/log/mongodb-backup.log`
- Run manually: `sudo /usr/local/bin/mongodb-backup.sh`

## Security Notes

**For Production Use**:
1. Remove public SSH access (use bastion/SSM)
2. Use latest OS and MongoDB versions
3. Encrypt all volumes and S3 buckets
4. Implement least-privilege IAM policies
5. Enable S3 bucket versioning and MFA delete
6. Use private S3 buckets
7. Enable VPC Flow Logs
8. Implement WAF for load balancers
9. Use Secrets Manager for credentials
10. Enable CloudTrail and GuardDuty

## Support

For issues with Terraform deployment, check:
- `terraform.tfstate` for resource IDs
- AWS CloudFormation console for stack events
- CloudWatch Logs for application logs
- VPC Flow Logs for network debugging

## Integration with GitHub Actions

The `1-infrastructure-deploy.yml` workflow will:
1. Run `terraform validate`
2. Scan with tfsec, Checkov, Trivy
3. Run `terraform plan` on PRs
4. Run `terraform apply` on main branch pushes
5. Export outputs for use in application deployment

---

**Ready to deploy!** Run `terraform init && terraform plan` to get started.
