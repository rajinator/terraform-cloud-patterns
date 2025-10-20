# All VPC endpoints necessary for a private EKS cluster to function

# Associate Route53 private hosted zones from centralized VPC endpoints (if using centralized mode)
resource "aws_route53_zone_association" "private_zone_peer" {
  for_each = var.peering_zone_ids

  zone_id = each.value
  vpc_id  = var.vpc_id
}

# S3 Gateway endpoint for cluster image registry and storage
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.private_vpc_rtbs

  tags = var.common_tags
}

# Note: All other VPC interface endpoints (EC2, ECR, Logs, STS, ELB, Autoscaling, etc.)
# are now created using the terraform-aws-modules/vpc/aws module in the parent configuration.
# See the eks_cluster.tf file for the complete VPC endpoints configuration using the module.
#
# When using centralized VPC endpoints, this module only handles zone associations.
# When using local VPC endpoints, the main module creates all necessary interface endpoints.
