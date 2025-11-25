# GitHub Actions CI/CD Pipelines - Wiz Technical Exercise

This repository contains comprehensive CI/CD pipelines for the Wiz Technical Exercise v4, implementing DevSecOps best practices with multiple security controls.

## Overview

The pipelines automate the deployment of a two-tier web application (Tasky todo app) with MongoDB backend, incorporating security scanning at every stage.

## Workflows

### 1. Infrastructure Deployment (`1-infrastructure-deploy.yml`)
**Purpose**: Deploy AWS infrastructure using Terraform IaC

**Triggers**: 
- Push to `main` branch (terraform/** changes)
- Pull requests
- Manual workflow dispatch

**Security Controls**:
- **tfsec**: Terraform static analysis
- **Checkov**: Policy-as-code scanning
- **Trivy**: IaC vulnerability scanning
- Terraform plan review on PRs

**Jobs**:
1. `terraform-validate`: Format check, init, validate
2. `security-scan-iac`: Multi-scanner security analysis
3. `terraform-plan`: Generate and review plan
4. `terraform-apply`: Deploy infrastructure (main branch only)
5. `terraform-destroy`: Teardown environment (manual only)

### 2. Application Build & Deploy (`2-app-build-deploy.yml`)
**Purpose**: Build, scan, and deploy containerized application

**Triggers**:
- Push to `main` branch (code changes)
- Pull requests
- Manual workflow dispatch

**Security Controls**:
- **golangci-lint**: Go code linting
- **Go tests**: Unit testing with coverage
- **Gosec**: Go security scanner (SAST)
- **Semgrep**: Multi-language SAST
- **govulncheck**: Go vulnerability database
- **Nancy**: Dependency vulnerability scanning
- **Trivy**: Container image scanning
- **Grype**: Container vulnerability scanning
- **Docker Scout**: CVE scanning
- **Kubesec**: Kubernetes security analysis

**Jobs**:
1. `code-quality`: Linting, testing, coverage
2. `sast-scanning`: Static application security testing
3. `dependency-scan`: Vulnerability detection
4. `build-container`: Docker build with multi-scanner validation
5. `verify-container`: Validate wizexercise.txt presence
6. `deploy-kubernetes`: Deploy to EKS cluster
7. `runtime-security-scan`: Runtime security validation

**wizexercise.txt Validation**:
The pipeline creates a `wizexercise.txt` file during build containing:
- GitHub username
- Build date
- Exercise name
- Repository details
- Commit SHA

This file is copied into the container and verified post-deployment.

### 3. Security Monitoring (`3-security-monitoring.yml`)
**Purpose**: Continuous security monitoring and compliance

**Schedule**: Daily at 2 AM UTC

**Checks**:
- Container image vulnerability scanning
- Kubernetes security audit (kube-bench, Polaris)
- Infrastructure drift detection
- Cloud security posture monitoring
- Exposed resources detection

### 4. Pull Request Checks (`4-pull-request-checks.yml`)
**Purpose**: Automated PR validation and security checks

**Triggers**: PR opened/synchronized/reopened

**Checks**:
- Semantic commit validation
- Secret detection (Trufflehog)
- Sensitive file detection
- Dependency review
- CodeQL analysis
- PR size validation
- License compliance

### 5. Backup Validation (`5-backup-validation.yml`)
**Purpose**: Validate MongoDB backup automation

**Schedule**: Daily at 3 AM UTC

**Checks**:
- Backup existence validation
- Backup size verification
- Backup contents listing
- Public access testing (intentional misconfiguration)
- Encryption configuration check
- Retention policy verification

## Required Secrets

Configure these secrets in GitHub repository settings:

### AWS Credentials
- `AWS_ROLE_ARN`: IAM role ARN for OIDC authentication
- `AWS_REGION`: AWS region (e.g., us-east-1)

### Kubernetes
- `EKS_CLUSTER_NAME`: EKS cluster name
- `MONGODB_URI`: MongoDB connection string
- `SECRET_KEY`: Application secret key

### Backup
- `BACKUP_BUCKET_NAME`: S3 bucket for MongoDB backups

### Optional (Enhanced Security)
- `SNYK_TOKEN`: Snyk API token for container scanning
- `CODECOV_TOKEN`: Codecov token for coverage reporting

## Setup Instructions

### 1. Configure AWS OIDC

```bash
# Create OIDC provider for GitHub Actions
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### 2. Create IAM Role

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:OWNER/REPO:*"
        }
      }
    }
  ]
}
```

### 3. Configure Secrets

Go to repository Settings → Secrets and variables → Actions → New repository secret

### 4. Enable Required GitHub Features

- Enable GitHub Actions
- Enable Dependabot alerts
- Enable Code scanning (CodeQL)
- Enable Secret scanning

## Pipeline Execution Flow

### Pull Request Flow
1. PR opened → `4-pull-request-checks.yml` runs
2. Code changes → `2-app-build-deploy.yml` (build only, no deploy)
3. Terraform changes → `1-infrastructure-deploy.yml` (plan only)

### Main Branch Flow
1. Push to main → All pipelines trigger
2. Infrastructure changes → Terraform apply
3. Application changes → Build, scan, deploy to Kubernetes
4. Deployment verification → Smoke tests

### Scheduled Flow
1. Daily 2 AM UTC → Security monitoring
2. Daily 3 AM UTC → Backup validation

## Intentional Security Misconfigurations (Per Exercise)

The following security issues are **intentionally configured** for the Wiz Technical Exercise to demonstrate security tool effectiveness:

### Infrastructure
- VM with outdated Linux version (1+ year old)
- SSH exposed to public internet (0.0.0.0/0)
- Overly permissive IAM roles (VM can create VMs)
- Outdated MongoDB version (1+ year old)
- S3 bucket with public read access

### Kubernetes
- Privileged containers
- Cluster-admin RBAC permissions
- Containers running as root
- Privilege escalation enabled

### Application
- Potential JWT vulnerabilities
- MongoDB injection risks

These issues should be detected by the security scanning tools in the pipeline.

## Monitoring and Alerts

### Failed Workflows
- Check Actions tab for failed runs
- Review security scan results in Security tab
- Check Issues for automated alerts

### Security Findings
- Navigate to Security → Code scanning alerts
- Review Dependabot alerts
- Check Secret scanning alerts

## Demonstration Commands

### Verify Deployment
```bash
# Connect to EKS cluster
aws eks update-kubeconfig --name <cluster-name> --region <region>

# Check all resources
kubectl get all -n tasky-app

# Verify wizexercise.txt
kubectl exec -it deployment/tasky-deployment -n tasky-app -- cat /app/wizexercise.txt

# Check application logs
kubectl logs -f deployment/tasky-deployment -n tasky-app

# Test application
kubectl get ingress -n tasky-app
curl http://<ingress-url>
```

### Security Scanning Results
```bash
# View container vulnerabilities
gh api repos/:owner/:repo/code-scanning/alerts

# Check Terraform issues
cat terraform/tfsec-results.sarif
```

## Presentation Tips

1. **Start with Architecture Diagram**: Show the two-tier application structure
2. **Walk Through Pipelines**: Demonstrate each workflow's purpose
3. **Show Security Controls**: Highlight multiple scanning tools
4. **Demonstrate Failures**: Show how security issues are caught
5. **Live kubectl Demo**: Prove application is running and functioning
6. **Show wizexercise.txt**: Verify file exists in container
7. **Discuss Misconfigurations**: Explain intentional security issues
8. **Value Proposition**: How security tools reduce risk

## Troubleshooting

### Pipeline Failures
- Check workflow logs in Actions tab
- Verify secrets are configured correctly
- Ensure AWS permissions are adequate

### Deployment Issues
- Check kubectl connectivity
- Verify EKS cluster exists
- Review pod logs for errors

### Security Scan Failures
- Review SARIF files in Security tab
- Check if issues are intentional (per exercise)
- Update security policies if needed

## Clean Up

To destroy all resources:

```bash
# Via GitHub Actions
# Go to Actions → Infrastructure Deployment → Run workflow → Select 'destroy'

# Or manually
cd terraform
terraform destroy
```

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Wiz Security Platform](https://www.wiz.io/)
