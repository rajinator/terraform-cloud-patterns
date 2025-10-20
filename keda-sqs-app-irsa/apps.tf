module "irsa" {
  for_each = local.applications

  source = "./modules/irsa"

  app_name            = each.key
  app_namespace       = each.value.namespace
  app_service_account = each.value.service_account
  sqs_queue_arn       = each.value.sqs_queue_arn
  oidc_provider_url   = var.oidc_provider_url
}