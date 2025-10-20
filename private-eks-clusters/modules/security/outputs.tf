output "worker_group_mgmt_sg" {
  description = "SG for worker group management"
  value       = aws_security_group.worker_group_mgmt_sg
}

output "vpcendpoints_access" {
  description = "SG for VPC endpoint access"
  value       = aws_security_group.vpcendpoints_access
}