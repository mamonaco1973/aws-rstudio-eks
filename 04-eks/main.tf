# ==============================================================================
# Terraform and Provider Configuration
# ------------------------------------------------------------------------------
# Defines required providers, AWS region, and basic identity data sources.
# ==============================================================================

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm" # Use the official HashiCorp Helm provider
      version = ">= 2.10.0"      # Require Helm provider version 2.10.0 or newer
    }
  }
}

# ------------------------------------------------------------------------------
# AWS Provider Configuration
# ------------------------------------------------------------------------------
# Specifies the AWS region used for all resources in this environment.
# ------------------------------------------------------------------------------
provider "aws" {
  region = "us-east-1" # Default AWS region for deployment
}

# ------------------------------------------------------------------------------
# AWS Data Sources
# ------------------------------------------------------------------------------
# Retrieve the current AWS account ID and active region for dynamic references.
# ------------------------------------------------------------------------------
data "aws_caller_identity" "current" {} # Returns the AWS account ID and ARN
data "aws_region" "current" {}          # Returns the currently configured region


# ------------------------------------------------------------------------------------------
# Secrets Manager: AD Admin Credentials
# - Retrieves stored secret for AD administrator credentials
# ------------------------------------------------------------------------------------------
data "aws_secretsmanager_secret" "admin_secret" {
  name = "admin_ad_credentials"
}
