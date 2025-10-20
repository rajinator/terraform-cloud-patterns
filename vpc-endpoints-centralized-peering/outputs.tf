################################################################################
# VPC Endpoints Outputs
################################################################################

output "phz_zones" {
  description = "Map of created private hosted zones with zone IDs and names"
  value       = module.vpc_endpoints.phz_zones
}

output "phz_ec2api" {
  description = "EC2 API private hosted zone information"
  value       = module.vpc_endpoints.phz_ec2api
}

output "vpc_endpoints" {
  description = "Map of created VPC endpoints with details"
  value       = module.vpc_endpoints.vpc_endpoints
}

output "security_group_id" {
  description = "Security group ID attached to VPC endpoints"
  value       = module.security.vpcendpoints_access.id
}

# output "ec2_vpcendpoint" {
#   description = "EC2 VPC Interface endpoint"
#   value       = module.vpc_endpoints.ec2_vpcendpoint.dns_entry[0]
# }

# output "phz_ec2_endpoint" {
#   description = "EC2 VPC endpoint aws com zone"
#   value       = module.vpc_endpoints.ec2_zone_awscom.id
# }
