variable "oidc_provider_url" {
  description = "OIDC provider URL for the EKS cluster"
  type        = string
}

variable "region" {
  description = "AWS region to use for the module"
  type        = string
}