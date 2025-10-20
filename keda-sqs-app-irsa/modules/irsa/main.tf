module "iam_assumable_role_keda" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "3.6.0"
  create_role                   = true
  role_name                     = "${var.app_name}-irsa"
  provider_url                  = var.oidc_provider_url
  role_policy_arns              = [aws_iam_policy.keda_sqs_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${var.app_namespace}:${var.app_service_account}"]
}

resource "aws_iam_policy" "keda_sqs_policy" {
  name_prefix = "${var.app_name}-irsa-"
  description = "IRSA policy for ${var.app_name} SQS scaler"
  policy      = data.aws_iam_policy_document.keda_sqs_policy.json
}

data "aws_iam_policy_document" "keda_sqs_policy" {
  statement {
    sid    = "KEDASQS"
    effect = "Allow"

    actions = [
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:ChangeMessageVisibility"
    ]

    resources = [var.sqs_queue_arn]
  }
}
