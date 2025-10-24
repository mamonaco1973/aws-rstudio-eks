#!/bin/bash
# ------------------------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------------------------
export AWS_DEFAULT_REGION="us-east-1"   # AWS region for all deployed resources


# ------------------------------------------------------------------------------------------------
# Destroy EC2 server instances
# ------------------------------------------------------------------------------------------------
echo "NOTE: Destroying EC2 server instances..."

cd 02-servers || { echo "ERROR: Directory 02-servers not found"; exit 1; }
terraform init
terraform destroy -auto-approve
cd .. || exit

# ------------------------------------------------------------------------------------------------
# Delete AD secrets and destroy AD Domain Controller
# ------------------------------------------------------------------------------------------------
echo "NOTE: Deleting AD-related AWS secrets and parameters..."

# Permanently delete AD credentials from Secrets Manager
# WARNING: No recovery window; secrets are gone immediately.

for secret in \
    akumar_ad_credentials \
    jsmith_ad_credentials \
    edavis_ad_credentials \
    rpatel_ad_credentials \
    rstudio_credentials \
    admin_ad_credentials; do

    aws secretsmanager delete-secret \
        --secret-id "$secret" \
        --force-delete-without-recovery
done

aws ecr delete-repository --repository-name "rstudio" --force || {
    echo "WARNING: Failed to delete ECR repository. It may not exist."
}

echo "NOTE: Destroying AD instance..."

cd 01-directory || { echo "ERROR: Directory 01-directory not found"; exit 1; }
terraform init
terraform destroy -auto-approve
cd .. || exit

# ------------------------------------------------------------------------------------------------
# Completion
# ------------------------------------------------------------------------------------------------
echo "NOTE: Infrastructure teardown complete."
