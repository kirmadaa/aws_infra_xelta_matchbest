output "cluster_name" { value = aws_eks_cluster.main.name }
output "node_security_group_id" { value = aws_security_group.nodes.id }