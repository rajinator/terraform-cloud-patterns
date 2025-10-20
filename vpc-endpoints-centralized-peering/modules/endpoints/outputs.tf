output "phz_zones" {
  description = "Map of created private hosted zones with their zone IDs"
  value = {
    for zone_key, zone in aws_route53_zone.private :
    zone_key => {
      zone_id = zone.zone_id
      name    = zone.name
    }
  }
}

output "phz_ec2api" {
  description = "Created private hosted zone for EC2 API endpoint"
  value = length(aws_route53_zone.ec2api) > 0 ? {
    zone_id = aws_route53_zone.ec2api[0].zone_id
    name    = aws_route53_zone.ec2api[0].name
  } : null
}

output "vpc_endpoints" {
  description = "Map of created VPC endpoints"
  value = {
    for ep_key, ep in aws_vpc_endpoint.private :
    ep_key => {
      id           = ep.id
      arn          = ep.arn
      service_name = ep.service_name
      dns_entry    = ep.dns_entry
    }
  }
}

# output "ec2_vpcendpoint" {
#   description = "EC2 VPC Interface endpoint"
#   value       = aws_vpc_endpoint.private["ec2"]
# }

# output "ec2_zone_awscom" {
#   description = "EC2 VPC endpoint aws com zone"
#   value       = aws_route53_zone.private_ec2_endpoint_aws_com
# }

# output "ecr_api_vpcendpoint" {
#   description = "ECR API VPC Interface endpoint"
#   value       = aws_vpc_endpoint.ecr-api
# }

# output "ecr_dkr_vpcendpoint" {
#   description = "ECR API VPC Interface endpoint"
#   value       = aws_vpc_endpoint.ecr-dkr
# }

# output "s3_vpcendpoint" {
#   description = "S3 VPC Interface endpoint"
#   value       = aws_vpc_endpoint.s3
# }

# output "logs_vpcendpoint" {
#   description = "Logs VPC Interface endpoint"
#   value       = aws_vpc_endpoint.logs
# }

# output "sts_vpcendpoint" {
#   description = "STS VPC Interface endpoint"
#   value       = aws_vpc_endpoint.sts
# }

# output "elb_vpcendpoint" {
#   description = "ELB VPC Interface endpoint"
#   value       = aws_vpc_endpoint.elb
# }

# output "autoscaling_vpcendpoint" {
#   description = "Autoscaling VPC Interface endpoint"
#   value       = aws_vpc_endpoint.autoscaling
# }

# output "appmesh_envoy_mgmt_vpcendpoint" {
#   description = "Autoscaling VPC Interface endpoint"
#   value       = aws_vpc_endpoint.appmesh-envoy-mgmt
# }
