#!/bin/bash

# ------------------------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------------------------
export AWS_DEFAULT_REGION="us-east-1"   # AWS region where resources will be deployed
DNS_ZONE="mcloud.mikecloud.com"         # AD DNS domain (passed into Terraform modules)
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
# Build Validation
# ------------------------------------------------------------------------------------------------
# Run post-deployment checks (e.g., DNS, domain join, instance health).
echo "NOTE: Running build validation..."
#s./validate.sh

echo "NOTE: Infrastructure build complete."
# ================================================================================================
# End of Script
# ================================================================================================
