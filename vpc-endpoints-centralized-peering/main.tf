################################################################################
# VPC Endpoints Centralized Architecture
################################################################################
# This configuration creates centralized VPC endpoints in a network/shared VPC
# and shares them across multiple spoke VPCs using Route53 private hosted zones
################################################################################

data "aws_vpc" "selected" {
  id = var.vpc_id
}

################################################################################
# Security Module
################################################################################
# Creates security groups and network ACLs for VPC endpoint access

module "security" {
  source = "./modules/security"

  vpc_id                  = data.aws_vpc.selected.id
  region                  = var.region
  private_subnet_ids      = var.private_subnet_ids
  multi_account_vpc_cidrs = var.multi_account_vpc_cidrs
  environment             = var.environment
  default_tags            = var.default_tags
}

################################################################################
# VPC Endpoints Module
################################################################################
# Creates VPC interface endpoints, Route53 private hosted zones, and zone associations

module "vpc_endpoints" {
  source = "./modules/endpoints"

  # Ensure security groups are created first
  depends_on = [module.security]

  vpc_id                  = data.aws_vpc.selected.id
  region                  = var.region
  eps_map                 = var.eps_map
  private_subnet_ids      = var.private_subnet_ids
  private_vpc_rtbs        = var.private_vpc_rtbs
  if_security_group_id    = module.security.vpcendpoints_access.id
  multi_account_vpc_cidrs = var.multi_account_vpc_cidrs
  vpcs_map                = var.vpcs_map
  environment             = var.environment
  default_tags            = var.default_tags
}
