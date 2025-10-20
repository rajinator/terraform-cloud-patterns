variable "vpc_id" {
  description = "VPC ID where VPC endpoints will be created"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs where endpoint ENIs will be attached"
  type        = list(string)
}

variable "private_vpc_rtbs" {
  description = "List of private VPC route table IDs for gateway endpoints"
  type        = list(string)
}

variable "if_security_group_id" {
  description = "Security group ID to attach to VPC interface endpoints"
  type        = string
}

variable "multi_account_vpc_cidrs" {
  description = "List of CIDR blocks from spoke VPCs"
  type        = list(string)
}

variable "eps_map" {
  description = "Map of endpoint configurations"
  type = map(object({
    name     = string
    shortdns = string
  }))
}

variable "vpcs_map" {
  description = "Map of VPC names to VPC IDs for Route53 zone associations"
  type        = map(string)
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default     = {}
}
