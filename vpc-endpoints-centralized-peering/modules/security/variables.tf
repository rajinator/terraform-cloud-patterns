variable "vpc_id" {
  description = "VPC ID where security resources will be created"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "multi_account_vpc_cidrs" {
  description = "List of CIDR blocks from spoke VPCs that need access to VPC endpoints"
  type        = list(string)
}

variable "environment" {
  description = "Environment name (e.g., shared-services, network)"
  type        = string
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default     = {}
}
