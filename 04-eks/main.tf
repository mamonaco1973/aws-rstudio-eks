terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.10.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" 
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}