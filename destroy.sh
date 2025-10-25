#!/bin/bash
# ------------------------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------------------------
export AWS_DEFAULT_REGION="us-east-1"   # AWS region for all deployed resources
set -euo pipefail

# ------------------------------------------------------------------------------------------------
# Destroy EKS Cluster
# ------------------------------------------------------------------------------------------------
echo "NOTE: Destroying EKS cluster..."

cd 04-eks || { echo "ERROR: Directory 04-eks not found"; exit 1; }
terraform init
echo "NOTE: Deleting nginx_ingress."
terraform destroy -target=helm_release.nginx_ingress  -auto-approve > /dev/null 2> /dev/null
terraform destroy -auto-approve
cd .. || exit

# ------------------------------------------------------------------------------------------------
# Delete Orphaned Security Groups Named "k8s*"
# AWS sometimes leaves dangling security groups after EKS deletion
# ------------------------------------------------------------------------------------------------

# Query AWS for security group IDs where the group name starts with "k8s"
group_ids=$(aws ec2 describe-security-groups \
  --query "SecurityGroups[?starts_with(GroupName, 'k8s')].GroupId" \
  --output text)

# If no matching groups found, skip deletion logic
if [ -z "$group_ids" ]; then
  echo "NOTE: No security groups starting with 'k8s' found."
fi

# Loop through each security group ID and attempt deletion
for group_id in $group_ids; do
  echo "NOTE: Deleting security group: $group_id"
  aws ec2 delete-security-group --group-id "$group_id"

  # Check if deletion was successful and log accordingly
  if [ $? -eq 0 ]; then
    echo "NOTE: Successfully deleted $group_id"
  else
    echo "WARNING: Failed to delete $group_id — possibly still in use by another resource"
  fi
done

exit 0

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
