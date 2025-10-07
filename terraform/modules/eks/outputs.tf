output "cluster_name" {
  description = "The name of the EKS cluster."
  value       = aws_eks_cluster.main.name
}

output "node_security_group_id" {
  description = "The ID of the security group used by the EKS nodes (inherited from the cluster)."
  value       = aws_security_group.cluster.id
}

output "alb_controller_role_arn" {
  description = "The ARN of the IAM role for the AWS Load Balancer Controller."
  value       = aws_iam_role.alb_controller.arn
}