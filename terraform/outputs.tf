output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "Endpoint for EKS cluster"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_security_group.eks_cluster.id
}

output "eks_cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.main.arn
}

output "eks_cluster_certificate_authority" {
  description = "Certificate authority data for the EKS cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "eks_oidc_provider_arn" {
  description = "ARN of the OIDC provider for EKS"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "mongodb_instance_id" {
  description = "ID of the MongoDB EC2 instance"
  value       = aws_instance.mongodb.id
}

output "mongodb_instance_private_ip" {
  description = "Private IP address of MongoDB instance"
  value       = aws_instance.mongodb.private_ip
}

output "mongodb_instance_public_ip" {
  description = "Public IP address of MongoDB instance"
  value       = aws_eip.mongodb.public_ip
}

output "mongodb_security_group_id" {
  description = "Security group ID for MongoDB instance"
  value       = aws_security_group.mongodb.id
}

output "mongodb_connection_string" {
  description = "MongoDB connection string for the application"
  value       = "mongodb://taskyapp:TaskyApp123!@${aws_instance.mongodb.private_ip}:27017/tasky?authSource=tasky"
  sensitive   = true
}

output "mongodb_ssh_command" {
  description = "SSH command to connect to MongoDB instance"
  value       = "ssh -i terraform/ssh-keys/mongodb-key ubuntu@${aws_eip.mongodb.public_ip}"
}

output "backup_bucket_name" {
  description = "Name of the S3 bucket for MongoDB backups"
  value       = aws_s3_bucket.mongodb_backups.id
}

output "backup_bucket_arn" {
  description = "ARN of the S3 bucket for MongoDB backups"
  value       = aws_s3_bucket.mongodb_backups.arn
}

output "backup_bucket_url" {
  description = "URL of the S3 bucket (publicly accessible)"
  value       = "https://${aws_s3_bucket.mongodb_backups.bucket}.s3.${var.aws_region}.amazonaws.com"
}

output "terraform_state_bucket" {
  description = "S3 bucket for Terraform state (for future use)"
  value       = aws_s3_bucket.terraform_state.id
}

output "terraform_lock_table" {
  description = "DynamoDB table for Terraform state locking"
  value       = aws_dynamodb_table.terraform_locks.id
}

output "load_balancer_controller_policy_arn" {
  description = "ARN of the AWS Load Balancer Controller IAM policy"
  value       = aws_iam_policy.aws_load_balancer_controller.arn
}

output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.main.name} --region ${var.aws_region}"
}

output "intentional_misconfigurations" {
  description = "List of intentional security misconfigurations for the exercise"
  value = {
    mongodb_ec2 = {
      ssh_exposed          = "SSH exposed to 0.0.0.0/0"
      outdated_os          = "Ubuntu 20.04 LTS (1+ year old)"
      outdated_mongodb     = "MongoDB ${var.mongodb_version} (outdated)"
      overly_permissive_iam = "IAM role can create EC2 instances"
      unencrypted_volume   = "Root volume not encrypted"
    }
    s3_backup_bucket = {
      public_read_access = "Bucket allows public read and list"
      no_encryption      = "Server-side encryption not configured"
    }
    kubernetes = {
      privileged_containers       = "Deployment uses privileged: true"
      cluster_admin_role          = "Service account has cluster-admin"
      run_as_root                 = "Containers run as root"
      privilege_escalation_allowed = "allowPrivilegeEscalation: true"
    }
  }
}

output "next_steps" {
  description = "Next steps after infrastructure deployment"
  value = <<-EOT
    Infrastructure deployed successfully!
    
    Next Steps:
    1. Configure kubectl:
       ${self.kubectl_config_command}
    
    2. SSH to MongoDB instance:
       ${self.mongodb_ssh_command}
    
    3. Get MongoDB connection string (for GitHub secret MONGODB_URI):
       ${nonsensitive(self.mongodb_connection_string)}
    
    4. Set GitHub Secrets:
       - AWS_ROLE_ARN: (Create GitHub Actions OIDC role)
       - AWS_REGION: ${var.aws_region}
       - EKS_CLUSTER_NAME: ${self.eks_cluster_name}
       - MONGODB_URI: ${nonsensitive(self.mongodb_connection_string)}
       - SECRET_KEY: (Generate with: openssl rand -hex 32)
       - BACKUP_BUCKET_NAME: ${self.backup_bucket_name}
    
    5. Verify MongoDB backup bucket (publicly accessible):
       ${self.backup_bucket_url}
    
    6. Deploy application via GitHub Actions workflow
  EOT
}
