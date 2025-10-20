# VPC and Networking Configuration

data "aws_availability_zones" "available" {
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

# Security Groups and NACLs Module
module "security" {
  source             = "./modules/security"
  vpc_id             = data.aws_vpc.selected.id
  region             = var.region
  private_subnet_ids = var.private_subnet_ids
  common_tags        = local.common_tags
}

# Optional: Create local VPC endpoints or use centralized endpoints from another VPC
module "vpc_endpoints" {
  count = var.create_vpc_endpoints ? 1 : 0
  
  # Adds dependency on base SGs to be created first
  depends_on            = [module.security]
  source                = "./modules/endpoints"
  vpc_id                = data.aws_vpc.selected.id
  region                = var.region
  private_subnet_ids    = var.private_subnet_ids
  private_vpc_rtbs      = var.private_vpc_rtbs
  if_security_group_id  = module.security.vpcendpoints_access.id
  peering_zone_ids      = var.peering_zone_ids
  common_tags           = local.common_tags
}

# These NACL rules specifically need the prefix-list for S3 endpoint Gateway to be in place before creation
# Only created when VPC endpoints are enabled locally
data "aws_vpc_endpoint" "s3_ep" {
  count        = var.create_vpc_endpoints ? 1 : 0
  vpc_id       = data.aws_vpc.selected.id
  service_name = "com.amazonaws.${var.region}.s3"
  depends_on   = [module.vpc_endpoints]
}

data "aws_prefix_list" "s3_ep" {
  count          = var.create_vpc_endpoints ? 1 : 0
  prefix_list_id = data.aws_vpc_endpoint.s3_ep[0].prefix_list_id
}

resource "aws_network_acl_rule" "s3_endpoint_pl_inbound_api_port" {
  count          = var.create_vpc_endpoints ? 3 : 0
  network_acl_id = var.private_vpc_nacl_id
  rule_number    = "21${count.index}"
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = data.aws_prefix_list.s3_ep[0].cidr_blocks[count.index]
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "s3_endpoint_pl_inbound_data_ports" {
  count          = var.create_vpc_endpoints ? 3 : 0
  network_acl_id = var.private_vpc_nacl_id
  rule_number    = "22${count.index}"
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = data.aws_prefix_list.s3_ep[0].cidr_blocks[count.index]
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "s3_endpoint_pl_outbound_api_port" {
  count          = var.create_vpc_endpoints ? 3 : 0
  network_acl_id = var.private_vpc_nacl_id
  rule_number    = "21${count.index}"
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = data.aws_prefix_list.s3_ep[0].cidr_blocks[count.index]
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "s3_endpoint_pl_outbound_data_ports" {
  count          = var.create_vpc_endpoints ? 3 : 0
  network_acl_id = var.private_vpc_nacl_id
  rule_number    = "22${count.index}"
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = data.aws_prefix_list.s3_ep[0].cidr_blocks[count.index]
  from_port      = 1024
  to_port        = 65535
}

# Tag subnets for ELB
resource "aws_ec2_tag" "private_subnet_elb_tag" {
  for_each    = toset(var.private_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "shared"
}

