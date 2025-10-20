################################################################################
# General Configuration
################################################################################

variable "region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
  
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-\\d{1}$", var.region))
    error_message = "Region must be a valid AWS region format (e.g., us-east-1, eu-west-1)."
  }
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "shared-services"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.environment))
    error_message = "Environment must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Purpose   = "VPC Endpoints Centralized"
  }
}

################################################################################
# VPC Configuration
################################################################################

variable "vpc_id" {
  description = "ID of the central/network VPC where endpoints will be created"
  type        = string
  
  validation {
    condition     = can(regex("^vpc-[a-f0-9]{8,}$", var.vpc_id))
    error_message = "VPC ID must be a valid format (vpc-xxxxxxxx)."
  }
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs where VPC endpoint ENIs will be attached"
  type        = list(string)
  
  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least 2 private subnets required for high availability."
  }
}

variable "private_vpc_rtbs" {
  description = "List of private VPC route table IDs to associate with gateway endpoints (e.g., S3, DynamoDB)"
  type        = list(string)
  default     = []
}

variable "private_vpc_nacl_id" {
  description = "ID of the private VPC Network ACL (currently unused but kept for future extensions)"
  type        = string
  default     = ""
}

################################################################################
# Multi-Account Configuration
################################################################################

variable "multi_account_vpc_cidrs" {
  description = "List of CIDR blocks from spoke/application VPCs that need access to centralized endpoints"
  type        = list(string)
  
  validation {
    condition = alltrue([
      for cidr in var.multi_account_vpc_cidrs : can(cidrhost(cidr, 0))
    ])
    error_message = "All elements must be valid CIDR blocks."
  }
}

variable "vpcs_map" {
  description = "Map of VPC names to VPC IDs for Route53 private hosted zone associations. Key = environment name, Value = VPC ID"
  type        = map(string)
  
  validation {
    condition = alltrue([
      for vpc_id in values(var.vpcs_map) : can(regex("^vpc-[a-f0-9]{8,}$", vpc_id))
    ])
    error_message = "All VPC IDs must be in valid format (vpc-xxxxxxxx)."
  }
}

################################################################################
# Endpoint Configuration
################################################################################

variable "eps_map" {
  description = <<-EOT
    Map of AWS service endpoints to create. Each entry should contain:
    - name: AWS service name for the endpoint
    - shortdns: Short DNS prefix for the private hosted zone
    
    Example:
    {
      "ec2" = {
        "name"     = "ec2"
        "shortdns" = "ec2"
      }
    }
  EOT
  type = map(object({
    name     = string
    shortdns = string
  }))
}