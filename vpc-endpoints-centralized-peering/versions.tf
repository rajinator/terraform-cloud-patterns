terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration should be provided via backend config file or CLI
  # Example: terraform init -backend-config=backend.hcl
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "vpc-endpoints-centralized/terraform.tfstate"
  #   region = "us-east-1"
  #   # dynamodb_table = "terraform-state-lock"
  #   # encrypt        = true
  # }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = var.default_tags
  }
}
