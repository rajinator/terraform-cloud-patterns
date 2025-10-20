output "iam_role_arns" {
  description = "A map of application names to the ARNs of the created IAM roles."
  value = {
    for app_key, app_module in module.irsa :
    app_key => app_module.iam_role_arn
  }
}
