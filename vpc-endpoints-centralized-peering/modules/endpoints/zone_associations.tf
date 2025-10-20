################################################################################
# Route53 VPC Association Authorizations
################################################################################
# Authorizes spoke VPCs to associate with the private hosted zones
# Note: This only authorizes the association. The actual association must be
# performed from the spoke VPC account using aws_route53_zone_association

locals {
  # Create a flat list of all zone-vpc combinations
  zone_vpc_associations = flatten([
    for vpc_name, vpc_id in var.vpcs_map : [
      for endpoint_key, endpoint_config in var.eps_map : {
        vpc_name     = vpc_name
        vpc_id       = vpc_id
        endpoint_key = endpoint_key
        zone_id      = aws_route53_zone.private[endpoint_key].zone_id
      }
    ]
  ])

  # Create associations for EC2 API zone if EC2 endpoint exists
  ec2api_vpc_associations = contains(keys(var.eps_map), "ec2") ? [
    for vpc_name, vpc_id in var.vpcs_map : {
      vpc_name = vpc_name
      vpc_id   = vpc_id
      zone_id  = aws_route53_zone.ec2api[0].zone_id
    }
  ] : []
}

################################################################################
# Standard Endpoint Zone Associations
################################################################################

resource "aws_route53_vpc_association_authorization" "spoke_vpcs" {
  for_each = {
    for assoc in local.zone_vpc_associations :
    "${assoc.vpc_name}-${assoc.endpoint_key}" => assoc
  }

  vpc_id  = each.value.vpc_id
  zone_id = each.value.zone_id
}

################################################################################
# EC2 API Zone Associations
################################################################################

resource "aws_route53_vpc_association_authorization" "spoke_vpcs_ec2api" {
  for_each = {
    for assoc in local.ec2api_vpc_associations :
    assoc.vpc_name => assoc
  }

  vpc_id  = each.value.vpc_id
  zone_id = each.value.zone_id
}
