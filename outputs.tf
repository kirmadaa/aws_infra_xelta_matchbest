# US East 1 Outputs
output "alb_dns_us_east_1" {
  description = "ALB DNS name in us-east-1"
  value       = module.alb_us_east_1.alb_dns_name
}

output "eks_cluster_name_us_east_1" {
  description = "EKS cluster name in us-east-1"
  value       = module.eks_us_east_1.cluster_name
}

output "eks_cluster_endpoint_us_east_1" {
  description = "EKS cluster endpoint in us-east-1"
  value       = module.eks_us_east_1.cluster_endpoint
  sensitive   = true
}

output "redis_endpoint_us_east_1" {
  description = "Redis endpoint in us-east-1"
  value       = var.enable_redis ? module.redis_us_east_1[0].redis_endpoint : "Redis disabled"
}

output "aurora_endpoint_us_east_1" {
  description = "Aurora writer endpoint in us-east-1"
  value       = var.enable_aurora ? module.aurora_us_east_1[0].cluster_endpoint : "Aurora disabled"
}

# EU Central 1 Outputs
output "alb_dns_eu_central_1" {
  description = "ALB DNS name in eu-central-1"
  value       = module.alb_eu_central_1.alb_dns_name
}

output "eks_cluster_name_eu_central_1" {
  description = "EKS cluster name in eu-central-1"
  value       = module.eks_eu_central_1.cluster_name
}

output "eks_cluster_endpoint_eu_central_1" {
  description = "EKS cluster endpoint in eu-central-1"
  value       = module.eks_eu_central_1.cluster_endpoint
  sensitive   = true
}

output "redis_endpoint_eu_central_1" {
  description = "Redis endpoint in eu-central-1"
  value       = var.enable_redis ? module.redis_eu_central_1[0].redis_endpoint : "Redis disabled"
}

output "aurora_endpoint_eu_central_1" {
  description = "Aurora writer endpoint in eu-central-1"
  value       = var.enable_aurora ? module.aurora_eu_central_1[0].cluster_endpoint : "Aurora disabled"
}

# AP South 1 Outputs
output "alb_dns_ap_south_1" {
  description = "ALB DNS name in ap-south-1"
  value       = module.alb_ap_south_1.alb_dns_name
}

output "eks_cluster_name_ap_south_1" {
  description = "EKS cluster name in ap-south-1"
  value       = module.eks_ap_south_1.cluster_name
}

output "eks_cluster_endpoint_ap_south_1" {
  description = "EKS cluster endpoint in ap-south-1"
  value       = module.eks_ap_south_1.cluster_endpoint
  sensitive   = true
}

output "redis_endpoint_ap_south_1" {
  description = "Redis endpoint in ap-south-1"
  value       = var.enable_redis ? module.redis_ap_south_1[0].redis_endpoint : "Redis disabled"
}

output "aurora_endpoint_ap_south_1" {
  description = "Aurora writer endpoint in ap-south-1"
  value       = var.enable_aurora ? module.aurora_ap_south_1[0].cluster_endpoint : "Aurora disabled"
}

# Global Outputs
output "route53_zone_id" {
  description = "Route53 hosted zone ID for xelta.ai"
  value       = data.aws_route53_zone.main.zone_id
}

output "route53_domain" {
  description = "Domain name configured in Route53"
  value       = var.domain_name
}

output "db_secret_arn" {
  description = "ARN of database credentials secret in Secrets Manager"
  value       = module.secrets.db_secret_arn
  sensitive   = true
}

output "kms_key_id" {
  description = "KMS key ID for encryption"
  value       = module.kms.kms_key_id
}

# kubectl configuration commands
output "kubectl_config_commands" {
  description = "Commands to configure kubectl for each EKS cluster"
  value = <<-EOT
# Configure kubectl for us-east-1
aws eks update-kubeconfig --region us-east-1 --name ${module.eks_us_east_1.cluster_name} --alias xelta-${var.environment}-us-east-1

# Configure kubectl for eu-central-1
aws eks update-kubeconfig --region eu-central-1 --name ${module.eks_eu_central_1.cluster_name} --alias xelta-${var.environment}-eu-central-1

# Configure kubectl for ap-south-1
aws eks update-kubeconfig --region ap-south-1 --name ${module.eks_ap_south_1.cluster_name} --alias xelta-${var.environment}-ap-south-1
EOT
}