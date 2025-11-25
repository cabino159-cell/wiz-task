# Required GitHub Secrets Configuration

Configure these secrets in your GitHub repository:
**Settings → Secrets and variables → Actions → New repository secret**

## AWS Configuration

### AWS_ROLE_ARN
- **Description**: ARN of the IAM role for GitHub Actions OIDC authentication
- **Example**: `arn:aws:iam::123456789012:role/GitHubActionsRole`
- **Required for**: Infrastructure deployment, Kubernetes deployment, backup validation

### AWS_REGION
- **Description**: AWS region where resources are deployed
- **Example**: `us-east-1`
- **Required for**: All AWS-related workflows

## Kubernetes Configuration

### EKS_CLUSTER_NAME
- **Description**: Name of the EKS cluster
- **Example**: `tasky-eks-cluster`
- **Required for**: Application deployment, security monitoring

### MONGODB_URI
- **Description**: MongoDB connection string
- **Example**: `mongodb://admin:password@mongodb-instance-ip:27017/tasky?authSource=admin`
- **Security Note**: Store as secret, never commit to repository
- **Required for**: Application deployment

### SECRET_KEY
- **Description**: Application secret key for JWT/session management
- **Example**: Generate with `openssl rand -hex 32`
- **Required for**: Application deployment

## Backup Configuration

### BACKUP_BUCKET_NAME
- **Description**: S3 bucket name for MongoDB backups
- **Example**: `tasky-mongodb-backups-12345`
- **Required for**: Backup validation workflow

## Optional Secrets (Enhanced Features)

### SNYK_TOKEN
- **Description**: Snyk API token for container vulnerability scanning
- **How to get**: Sign up at https://snyk.io and get API token
- **Required for**: Enhanced container scanning (optional)

### CODECOV_TOKEN
- **Description**: Codecov token for test coverage reporting
- **How to get**: Sign up at https://codecov.io and get token
- **Required for**: Coverage reporting (optional)

## Setting Up AWS OIDC Authentication

### 1. Create OIDC Provider

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### 2. Create IAM Role Trust Policy

Save as `trust-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/tasky-main:*"
        }
      }
    }
  ]
}
```

### 3. Create IAM Role

```bash
aws iam create-role \
  --role-name GitHubActionsRole \
  --assume-role-policy-document file://trust-policy.json
```

### 4. Attach Required Policies

```bash
# Full admin (for exercise - restrict in production)
aws iam attach-role-policy \
  --role-name GitHubActionsRole \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Or create custom policy with minimum required permissions
```

### 5. Get Role ARN

```bash
aws iam get-role --role-name GitHubActionsRole --query Role.Arn --output text
```

Use this ARN as the value for `AWS_ROLE_ARN` secret.

## Verification

After configuring secrets, verify by:

1. Go to repository **Settings → Secrets and variables → Actions**
2. Ensure all required secrets are listed
3. Run workflow manually to test authentication
4. Check workflow logs for authentication errors

## Security Best Practices

1. **Never commit secrets** to the repository
2. **Rotate secrets regularly** (every 90 days recommended)
3. **Use least privilege** IAM policies in production
4. **Enable secret scanning** in GitHub repository settings
5. **Review access logs** regularly
6. **Use environment-specific secrets** for dev/staging/prod

## Troubleshooting

### "Invalid AWS credentials" error
- Verify AWS_ROLE_ARN is correct
- Check trust policy includes your repository
- Ensure OIDC provider is created

### "Permission denied" errors
- Verify IAM role has required permissions
- Check CloudWatch logs for detailed errors

### "Secret not found" errors
- Verify secret names match exactly (case-sensitive)
- Check secret is configured in correct repository
