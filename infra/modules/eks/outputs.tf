output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.main.endpoint
  sensitive   = true
}

output "app_security_group_id" {
  description = "Security group ID used by application compute layer"
  value = var.compute_type == "node_group" ? (
    var.eks_node_sg_id
    ) : (
    aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  )
}

output "node_group_name" {
  description = "EKS node group name"
  value       = var.compute_type == "node_group" ? aws_eks_node_group.main[0].node_group_name : null
}

output "pod_identity_role_arn" {
  description = "Pod Identity IAM role ARN"
  value       = var.compute_type == "node_group" ? aws_iam_role.pod_identity_role[0].arn : null
}

output "pod_identity_association_id" {
  description = "EKS Pod Identity Association ID"
  value       = var.compute_type == "node_group" ? aws_eks_pod_identity_association.main[0].association_id : null
}
