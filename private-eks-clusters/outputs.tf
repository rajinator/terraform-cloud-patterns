################################################################################
# Cluster
################################################################################

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "The Kubernetes version for the cluster"
  value       = module.eks.cluster_version
}

output "cluster_platform_version" {
  description = "Platform version for the cluster"
  value       = module.eks.cluster_platform_version
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer (used for IRSA)"
  value       = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for EKS (used for IRSA)"
  value       = module.eks.oidc_provider_arn
}

################################################################################
# kubectl Configuration
################################################################################

output "configure_kubectl" {
  description = "Command to configure kubectl access to the cluster"
  value       = "aws eks --region ${var.region} update-kubeconfig --name ${module.eks.cluster_name}"
}

output "region" {
  description = "AWS region where the cluster is deployed"
  value       = var.region
}

################################################################################
# Node Groups
################################################################################

output "eks_managed_node_groups" {
  description = "Map of managed node groups and their attributes"
  value       = module.eks.eks_managed_node_groups
  sensitive   = true
}

output "eks_managed_node_groups_autoscaling_group_names" {
  description = "List of autoscaling group names for managed node groups"
  value       = module.eks.eks_managed_node_groups_autoscaling_group_names
}

################################################################################
# EKS Addons
################################################################################

output "cluster_addons" {
  description = "Map of all EKS cluster addons and their configurations"
  value       = module.eks.cluster_addons
}

################################################################################
# IRSA Roles
################################################################################

output "irsa_cluster_autoscaler_role_arn" {
  description = "ARN of the IAM role for Cluster Autoscaler (IRSA)"
  value       = module.iam_assumable_role_admin.this_iam_role_arn
}

output "irsa_cluster_autoscaler_role_name" {
  description = "Name of the IAM role for Cluster Autoscaler (IRSA)"
  value       = module.iam_assumable_role_admin.this_iam_role_name
}

################################################################################
# VPC Endpoints (conditional)
################################################################################

output "vpc_endpoints_created" {
  description = "Whether local VPC endpoints were created (vs using centralized)"
  value       = var.create_vpc_endpoints
}

output "vpc_endpoints" {
  description = "Map of VPC endpoints created (empty if using centralized endpoints)"
  value       = var.create_vpc_endpoints ? module.vpc_endpoints[0].endpoints : {}
}

################################################################################
# Security
################################################################################

output "security_group_vpc_endpoints" {
  description = "Security group ID for VPC endpoints access"
  value       = module.security.vpcendpoints_access.id
}

output "security_group_vpc_endpoints_name" {
  description = "Security group name for VPC endpoints access"
  value       = module.security.vpcendpoints_access.name
}
