output "iam_role_arn" {
  description = "The ARN of the created IAM role."
  value       = module.iam_assumable_role_keda.this_iam_role_arn
}
