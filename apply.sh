#!/bin/bash
# ==============================================================================
# Script Name: apply.sh
# Description:
#   Deploys a full AWS-based RStudio environment using Terraform and Docker.
#   Phases include:
#     1. Active Directory domain controller
#     2. EC2 servers joined to the domain
#     3. RStudio Docker image build and ECR push
#     4. EKS cluster deployment and kubeconfig update
#
# Requirements:
#   - AWS CLI v2, Terraform, Docker, jq installed
#   - AWS credentials with required permissions
#
# Author: [Your Name]
# ==============================================================================

# ------------------------------------------------------------------------------
# Global Configuration
# ------------------------------------------------------------------------------
export AWS_DEFAULT_REGION="us-east-1"  # Default AWS region for deployment
set -euo pipefail                      # Exit on error, unset var, or pipe fail

# ------------------------------------------------------------------------------
# Environment Pre-Check
# ------------------------------------------------------------------------------
echo "NOTE: Running environment validation..."
./check_env.sh
if [ $? -ne 0 ]; then
  echo "ERROR: Environment validation failed. Exiting."
  exit 1
fi

# ------------------------------------------------------------------------------
# Phase 1: Build Active Directory Domain Controller
# ------------------------------------------------------------------------------
# Deploys the AD instance using Terraform. This forms the authentication base
# and must complete before dependent components proceed.
echo "NOTE: Building Active Directory instance..."

cd 01-directory || { echo "ERROR: 01-directory not found."; exit 1; }

terraform init
terraform apply -auto-approve

cd .. || exit

# ------------------------------------------------------------------------------
# Phase 2: Build Dependent EC2 Servers
# ------------------------------------------------------------------------------
# These EC2 instances are domain-joined. They depend on AD being healthy and
# available before creation.
echo "NOTE: Building EC2 server instances..."

cd 02-servers || { echo "ERROR: 02-servers not found."; exit 1; }

terraform init
terraform apply -auto-approve

cd .. || exit

# ------------------------------------------------------------------------------
# Phase 3: Build RStudio Docker Image and Push to ECR
# ------------------------------------------------------------------------------
# Builds the RStudio Server Docker image and pushes it to AWS ECR for later use
# in the EKS cluster.
echo "NOTE: Building RStudio Docker image and pushing to ECR..."

cd 03-docker/rstudio || { echo "ERROR: rstudio directory missing."; exit 1; }

# Retrieve AWS Account ID dynamically for ECR reference
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
if [ -z "$AWS_ACCOUNT_ID" ]; then
  echo "ERROR: Failed to retrieve AWS Account ID. Exiting."
  exit 1
fi

# Authenticate Docker with AWS ECR using token-based login
aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | \
docker login --username AWS --password-stdin \
"${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com" || {
  echo "ERROR: Docker authentication failed. Exiting."
  exit 1
}

# Retrieve RStudio password from Secrets Manager
RSTUDIO_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id rstudio_credentials \
  --query 'SecretString' \
  --output text | jq -r '.password') 

if [ -z "$RSTUDIO_PASSWORD" ] || [ "$RSTUDIO_PASSWORD" = "null" ]; then
  echo "ERROR: Failed to retrieve RStudio password. Exiting."
  exit 1
fi

# Define full image tag and build Docker image
IMAGE_TAG="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/rstudio:rstudio-server-rc1"

#docker build \
# --build-arg RSTUDIO_PASSWORD="${RSTUDIO_PASSWORD}" \
# -t "${IMAGE_TAG}" . || {
# echo "ERROR: Docker build failed. Exiting."
#  exit 1
#}

# Push Docker image to ECR
#docker push "${IMAGE_TAG}" || {
#  echo "ERROR: Docker push failed. Exiting."
#  exit 1
#}

cd ../.. || exit

# ------------------------------------------------------------------------------
# Phase 4: Build EKS Cluster
# ------------------------------------------------------------------------------
# Deploys the EKS cluster via Terraform and updates kubeconfig for kubectl use.
echo "NOTE: Building EKS cluster..."

cd 04-eks || { echo "ERROR: 04-eks directory missing."; exit 1; }

terraform init
terraform apply -auto-approve

# Prepare Kubernetes YAML Manifests

# Replace placeholder in rstudio-deployment.yaml template with real image tag
sed "s|\${rstudio_image}|$IMAGE_TAG|g" yaml/rstudio-deployment.yaml.tmpl > ../rstudio-deployment.yaml || {
    echo "ERROR: Failed to generate Kubernetes deployment file. Exiting."
    exit 1
}
cp yaml/rstudio-service.yaml.tmpl  ../rstudio-service.yaml
cp yaml/rstudio-ingress.yaml.tmpl  ../rstudio-ingress.yaml

cd .. || exit

# ------------------------------------------------------------------------------
# Phase 5: Update kubeconfig and deploy rstudio yaml
# -----------------------------------------------------------------------------

# Update kubeconfig to connect kubectl to the EKS cluster
aws eks update-kubeconfig --name rstudio-cluster \
  --region ${AWS_DEFAULT_REGION} || {
  echo "ERROR: kubeconfig update failed. Exiting."
  exit 1
}

kubectl apply -f rstudio-deployment.yaml || {
  echo "ERROR: Failed to apply rstudio-deployment.yaml. Exiting."
  exit 1
}

kubectl apply -f rstudio-service.yaml || {
  echo "ERROR: Failed to apply rstudio-service.yaml. Exiting."
  exit 1
}

kubectl apply -f rstudio-ingress.yaml || {
  echo "ERROR: Failed to apply rstudio-ingress.yaml. Exiting."
  exit 1
}

# ------------------------------------------------------------------------------
# Phase 6: Build Validation
# ------------------------------------------------------------------------------
# Runs post-deployment checks for DNS, domain join, and instance health.
echo "NOTE: Running build validation..."
# ./validate.sh  # Uncomment once validation script is implemented

echo "NOTE: Infrastructure build complete."
# ==============================================================================
# End of Script
# ==============================================================================
