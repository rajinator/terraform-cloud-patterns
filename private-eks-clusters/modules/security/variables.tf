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

variable "common_tags" {
  type        = map(string)
  default     = {}
  description = "Common tags to apply to all resources"
}