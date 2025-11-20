# Security Best Practices

This document outlines the security posture and best practices implemented in this infrastructure.

## Network Security

### VPC Endpoints
All AWS service traffic (S3, DynamoDB, ECR, Secrets Manager, CloudWatch Logs) stays within the AWS network via VPC Endpoints.

**Benefits:**
- **No Internet Exposure**: ECR pulls, S3 access, and secret retrieval never traverse the internet
- **Cost Savings**: Reduced NAT Gateway data transfer charges (up to 90% savings on AWS service traffic)
- **Lower Latency**: Direct connections to AWS services

### Load Balancer Restrictions
**Application Load Balancer (ALB)**:
- ✅ Restricted to CloudFront managed prefix list only
- ✅ Prevents direct internet access, bypassing WAF
- ❌ Direct ALB access will return `403 Forbidden`

**Network Load Balancer (NLB)**:
- Internal only (not internet-facing)
- Restricted to VPC CIDR for ingress

### NAT Gateway Policy
- **Production**: Managed NAT Gateways REQUIRED (enforced via validation)
- **Dev/UAT**: EC2 NAT instances allowed for cost savings
- **Rationale**: EC2 NAT instances are single points of failure, unacceptable for prod

## Identity & Access Management (IAM)

### ECS Task Roles
Each application stack creates its own:
- `ecs_task_execution_role`: For pulling images, writing logs
- `ecs_task_role`: For application-specific permissions (DynamoDB, S3, SQS)

**Principle of Least Privilege**: Roles are scoped to specific resources using `${var.app_name}` in ARNs.

### Secret Management
**AWS Secrets Manager**:
- **Recovery Window**: 
  - Dev: 7 days
  - Prod/UAT: 30 days
- **Rationale**: Prevents immediate data loss on accidental deletion

**Rotation**: (Future enhancement)
- Use Lambda rotation functions
- Update `aws_secretsmanager_secret_rotation`

## Data Protection

### Encryption at Rest
- **DynamoDB**: AWS-managed encryption (default)
- **S3**: SSE-S3 encryption (default)
- **Secrets Manager**: KMS encryption (AWS managed key)

### Encryption in Transit
- **ALB → ECS**: HTTP (internal VPC traffic)
- **CloudFront → ALB**: HTTPS enforced via CloudFront settings
- **ECS → AWS Services**: HTTPS via VPC Endpoints

## Monitoring & Audit

### VPC Flow Logs
- **Enabled**: All VPC traffic logged to CloudWatch
- **Retention**: 7 days (configurable)
- **Use Case**: Security forensics, anomaly detection

### CloudWatch Logs
- All ECS container logs
- Lambda execution logs
- API Gateway access logs

### Recommended Additions
1. **AWS GuardDuty**: Threat detection
2. **AWS Config**: Compliance monitoring
3. **CloudTrail**: API audit logging

## Incident Response

### Compromised Credentials
1. **Rotate Immediately**: Use AWS Secrets Manager rotation
2. **Revoke Sessions**: Update IAM policies to deny `*` for the compromised role
3. **Audit**: Check CloudTrail for unauthorized API calls

### Security Group Breach
1. **Isolate**: Remove ingress rules immediately
2. **Snapshot**: Create EC2/RDS snapshots before termination
3. **Rebuild**: Use Terraform to recreate with hardened rules

### Data Exfiltration
1. **Check Flow Logs**: Look for unusual outbound traffic patterns
2. **S3 Access Logs**: Review bucket access for unauthorized downloads
3. **Block**: Update NACLs to block source IPs

## Compliance

### CIS AWS Foundations Benchmark
- ✅ VPC Flow Logs enabled
- ✅ Encryption at rest for S3/DynamoDB
- ✅ IAM password policy (managed externally)
- ❌ MFA for root account (manual setup required)
- ❌ CloudTrail enabled (recommended addition)

### GDPR Considerations
- **Data Residency**: Use region-specific deployments
- **Right to Deletion**: Implement S3 lifecycle with expiration
- **Data Portability**: Export DynamoDB to S3 for backups

## Security Checklist

Before deploying to production:
- [ ] Enable CloudTrail for all regions
- [ ] Configure AWS Config rules
- [ ] Enable GuardDuty
- [ ] Set up SNS alerts for security findings
- [ ] Review and tighten all security group rules
- [ ] Enable S3 bucket versioning for critical data
- [ ] Implement automated secret rotation
- [ ] Configure WAF rules (rate limiting, geo-blocking)
- [ ] Set up AWS Systems Manager Session Manager (no SSH keys!)
- [ ] Enable MFA for all IAM users with console access
