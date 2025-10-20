terraform {
    required_providers {
      aws = { version = ">= 2.28.1" }
      local = { version = ">= 2.0"}
      null = { version = ">= 3.1"}
      template = { version = ">= 2.1" }
      kubernetes = { version = ">= 2.20"}
    }

    # backend "s3" {
    #     bucket = "s3-state-state-bucket-for-your-org"
    #     region = "your-aws-region"
    #     key    = "iam-irsa-k8s"
    # }
}

provider "aws" {
    region = var.region
}