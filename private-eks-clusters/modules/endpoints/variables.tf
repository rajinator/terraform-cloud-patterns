variable "vpc_id" {
    description = "VPC ID"
    type        = string
}

variable "region" {
    description = "AWS region"
    type        = string
}

variable "private_subnet_ids" {
  type    = list(string)
}

variable "private_vpc_rtbs" {
  type    = list(string)
}

variable "if_security_group_id" {
  type    = string
}

variable "peering_zone_ids" {
  type    = map
  # default = ""
  
}

variable "common_tags" {
  type        = map(string)
  default     = {}
  description = "Common tags to apply to all resources"
}