variable "app_name" {
  description = "A unique name for the application"
  type        = string
}

variable "app_namespace" {
  description = "Kubernetes namespace for the application"
  type        = string
}

variable "app_service_account" {
  description = "Name of the application's service account"
  type        = string
}

variable "sqs_queue_arn" {
  description = "ARN of the SQS queue for the application to monitor"
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC provider URL for the EKS cluster"
  type        = string
}
