#!/bin/bash

# ------------------------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------------------------
export AWS_DEFAULT_REGION="us-east-1"   # AWS region where resources will be deployed
set -euo pipefail

# ------------------------------------------------------------------------------------------------
# Environment Pre-Check
# ------------------------------------------------------------------------------------------------
echo "NOTE: Running environment validation..."
./check_env.sh
if [ $? -ne 0 ]; then
  echo "ERROR: Environment check failed. Exiting."
  exit 1
fi

# ------------------------------------------------------------------------------------------------
# Phase 1: Build Active Directory Domain Controller
# ------------------------------------------------------------------------------------------------
echo "NOTE: Building Active Directory instance..."

cd 01-directory || { echo "ERROR: Directory 01-directory not found"; exit 1; }

terraform init
terraform apply -auto-approve

cd .. || exit

# ------------------------------------------------------------------------------------------------
# Phase 2: Build Dependent EC2 Servers
# ------------------------------------------------------------------------------------------------
# These servers join the AD domain; they must wait until AD is fully provisioned.
echo "NOTE: Building EC2 server instances..."

cd 02-servers || { echo "ERROR: Directory 02-servers not found"; exit 1; }

terraform init
terraform apply -auto-approve

cd .. || exit

# ------------------------------------------------------------------------------------------------
# Phase 3: Build RStudio Docker Container and Push to ECR
# ------------------------------------------------------------------------------------------------

cd 03-docker/rstudio || { echo "ERROR: Directory 03-docker/rstudio not found"; exit 1; }

# Get AWS Account ID dynamically to reference the correct ECR repo
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "ERROR: Failed to retrieve AWS Account ID. Exiting."
    exit 1
fi

# Authenticate Docker to AWS ECR using get-login-password and piping to login command
aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com || {
    echo "ERROR: Docker authentication to ECR failed. Exiting."
    exit 1
}

RSTUDIO_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id rstudio_credentials \
  --query 'SecretString' \
  --output text | jq -r '.password')

if [ -z "$RSTUDIO_PASSWORD" ] || [ "$RSTUDIO_PASSWORD" = "null" ]; then
    echo "ERROR: Failed to retrieve RStudio password from Secrets Manager. Exiting."
    exit 1
fi

IMAGE_TAG="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/rstudio:rstudio-server-rc1"

#docker build \
# --build-arg RSTUDIO_PASSWORD="${RSTUDIO_PASSWORD}" \
# -t "${IMAGE_TAG}" . || {
#   echo "ERROR: Docker build failed. Exiting."
#   exit 1
# }

#docker push "${IMAGE_TAG}" || {
#   echo "ERROR: Docker push failed. Exiting."
#   exit 1
#}

cd .

cd ../.. || exit
pwd 


# ------------------------------------------------------------------------------------------------
# Build Dependent EKS Cluster
# ------------------------------------------------------------------------------------------------

echo "NOTE: Building EKS cluster..."

cd 04-eks || { echo "ERROR: Directory 04-eks not found"; exit 1; }

terraform init
terraform apply -auto-approve

cd .. || exit

aws eks update-kubeconfig --name rstudio-eks-cluster --region us-east-1 || {
    echo "ERROR: Failed to update kubeconfig for EKS. Exiting."
    exit 1
}

# ------------------------------------------------------------------------------------------------
# Build Validation
# ------------------------------------------------------------------------------------------------
# Run post-deployment checks (e.g., DNS, domain join, instance health).
echo "NOTE: Running build validation..."
#s./validate.sh

echo "NOTE: Infrastructure build complete."
# ================================================================================================
# End of Script
# ================================================================================================
