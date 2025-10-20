variable "region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region"
}

variable "cluster_name" {
  type        = string
  default     = ""
  description = "EKS cluster name. If empty, uses 'eks-{workspace}'"
}

variable "create_vpc_endpoints" {
  type        = bool
  default     = true
  description = "Create VPC endpoints locally. Set to false if using centralized VPC endpoints from another VPC."
}

variable "cluster_admin_arns" {
  type        = list(string)
  default     = []
  description = "List of IAM role/user ARNs to grant cluster admin access. Simple way to add admins."
  
  # Example:
  # cluster_admin_arns = [
  #   "arn:aws:iam::123456789012:role/MyAdminRole",
  #   "arn:aws:iam::123456789012:role/DevOpsTeam"
  # ]
}

variable "map_accounts" {
  description = "Additional AWS account numbers to add to the aws-auth configmap. (Legacy - use cluster_admin_arns instead)"
  type        = list(string)
  default     = []
}

variable "map_roles" {
  description = "Additional IAM roles to add to the aws-auth configmap. (Legacy - use cluster_admin_arns instead)"
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

variable "map_users" {
  description = "Additional IAM users to add to the aws-auth configmap. (Legacy - use cluster_admin_arns instead)"
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))

  default = []
}

variable "vpc_id" {
  type    = string
}

variable "private_subnet_ids" {
  type    = list(string)
}

variable "private_vpc_rtbs" {
  type    = list(string)
}

variable "private_vpc_nacl_id" {
  type    = string
}

variable "eks_creation_phase" {
  type    = string
}

variable "eks_creation_public_access_ip" {
  type    = list(string)
  default = [""]
}

# For private k8s api access
variable "vpn_endpoint_cidr" {
  type    = string
  default = ""
}

variable "peered_vpc_cidrs" {
  type        = list(string)
  default     = []
  description = "List of CIDR blocks from peered VPCs that need private API access (e.g., shared services VPC, management VPC, on-premises networks)"
  
  # Example:
  # peered_vpc_cidrs = [
  #   "10.20.0.0/16",  # Shared services VPC
  #   "10.30.0.0/16",  # Management VPC
  #   "192.168.0.0/16" # On-premises network
  # ]
}

variable "peering_zone_ids" {
  type    = map
  # default = ""
  
}