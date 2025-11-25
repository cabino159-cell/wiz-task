variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "production"
}

variable "owner_email" {
  description = "Email of the resource owner"
  type        = string
  default     = "user@example.com"
}

variable "mongodb_uri" {
  description = "MongoDB connection URI"
  type        = string
  sensitive   = true
}

variable "secret_key" {
  description = "Application secret key"
  type        = string
  sensitive   = true
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "eks_cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.28"
}

variable "mongodb_instance_type" {
  description = "EC2 instance type for MongoDB"
  type        = string
  default     = "t3.medium"
}

# Intentional: Using outdated AMI (1+ year old)
variable "mongodb_ami" {
  description = "AMI ID for MongoDB EC2 instance (intentionally outdated)"
  type        = string
  default     = "ami-0866a3c8686eaeeba"  # Ubuntu 20.04 LTS (older version)
}

variable "mongodb_version" {
  description = "MongoDB version (intentionally outdated)"
  type        = string
  default     = "4.4"  # Outdated version (current is 7.x)
}

variable "ssh_allowed_cidr" {
  description = "CIDR blocks allowed to SSH (intentionally open)"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Intentional misconfiguration
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}
