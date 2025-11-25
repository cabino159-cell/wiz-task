# Security Group for MongoDB (Intentionally misconfigured)
resource "aws_security_group" "mongodb" {
  name        = "${local.name_prefix}-mongodb-sg"
  description = "Security group for MongoDB instance (intentionally misconfigured)"
  vpc_id      = aws_vpc.main.id

  # Intentional: SSH exposed to public internet
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidr  # 0.0.0.0/0
    description = "SSH from anywhere (INTENTIONAL MISCONFIGURATION)"
  }

  # MongoDB port - restricted to EKS nodes and VPC
  ingress {
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
    description     = "MongoDB from EKS cluster"
  }

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "MongoDB from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    local.common_tags,
    {
      Name                     = "${local.name_prefix}-mongodb-sg"
      IntentionalMisconfiguration = "SSH exposed to 0.0.0.0/0"
    }
  )
}

# IAM Role for MongoDB EC2 Instance (Intentionally overly permissive)
resource "aws_iam_role" "mongodb_ec2" {
  name = "${local.name_prefix}-mongodb-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = merge(
    local.common_tags,
    {
      IntentionalMisconfiguration = "Overly permissive role"
    }
  )
}

# Intentional: Overly permissive IAM policy (can create VMs)
resource "aws_iam_role_policy" "mongodb_ec2_permissions" {
  name = "${local.name_prefix}-mongodb-ec2-policy"
  role = aws_iam_role.mongodb_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:CreateTags",
          "ec2:DescribeInstances",
          "ec2:DescribeImages",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:TerminateInstances",
          "ec2:StopInstances",
          "ec2:StartInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.mongodb_backups.arn,
          "${aws_s3_bucket.mongodb_backups.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "mongodb" {
  name = "${local.name_prefix}-mongodb-instance-profile"
  role = aws_iam_role.mongodb_ec2.name

  tags = local.common_tags
}

# SSH Key Pair for MongoDB instance
resource "aws_key_pair" "mongodb" {
  key_name   = "${local.name_prefix}-mongodb-key"
  public_key = file("${path.module}/ssh-keys/mongodb-key.pub")  # You'll need to generate this

  tags = local.common_tags
}

# MongoDB EC2 Instance (Intentionally outdated)
resource "aws_instance" "mongodb" {
  ami                    = var.mongodb_ami  # Intentionally outdated Ubuntu
  instance_type          = var.mongodb_instance_type
  subnet_id              = aws_subnet.public[0].id  # In public subnet for SSH access
  vpc_security_group_ids = [aws_security_group.mongodb.id]
  iam_instance_profile   = aws_iam_instance_profile.mongodb.name
  key_name               = aws_key_pair.mongodb.key_name

  associate_public_ip_address = true

  user_data = templatefile("${path.module}/scripts/mongodb-userdata.sh", {
    mongodb_version = var.mongodb_version
    backup_bucket   = aws_s3_bucket.mongodb_backups.id
    aws_region      = var.aws_region
  })

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
    encrypted   = false  # Intentional: unencrypted for the exercise
  }

  tags = merge(
    local.common_tags,
    {
      Name                        = "${local.name_prefix}-mongodb"
      IntentionalMisconfiguration = "Outdated OS and MongoDB version, SSH exposed, overly permissive IAM"
    }
  )
}

# Elastic IP for MongoDB (optional, for stable IP)
resource "aws_eip" "mongodb" {
  instance = aws_instance.mongodb.id
  domain   = "vpc"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-mongodb-eip"
    }
  )

  depends_on = [aws_internet_gateway.main]
}
