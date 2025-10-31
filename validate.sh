#!/bin/bash
# ==============================================================================
# Wait for RStudio Ingress Load Balancer Address
# ------------------------------------------------------------------------------
# This script loops until the ingress resource gets a public hostname assigned.
# ==============================================================================

NAMESPACE="default"
INGRESS_NAME="rstudio-ingress"
MAX_ATTEMPTS=30
SLEEP_SECONDS=10

for ((i=1; i<=MAX_ATTEMPTS; i++)); do
  LB_ADDRESS=$(kubectl get ingress ${INGRESS_NAME} \
    --namespace ${NAMESPACE} \
    --output jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)

  if [[ -n "$LB_ADDRESS" ]]; then
    echo "NOTE: Load Balancer ready:"
    echo "NOTE: RStudio Ingress Load Balancer: $LB_ADDRESS"
    export LB_ADDRESS
    exit 0
  fi

  echo "WARNING: Attempt $i/${MAX_ATTEMPTS}: Load Balancer not ready yet... retrying in ${SLEEP_SECONDS}s"
  sleep ${SLEEP_SECONDS}
done

echo "ERROR: Timed out after ${MAX_ATTEMPTS} attempts waiting for Load Balancer address."
exit 1


# #!/bin/bash
# # --------------------------------------------------------------------------------------------------
# # Description:
# # This script queries AWS EC2 for instances tagged with specific names and outputs their
# # associated public DNS names. It is primarily used to quickly locate endpoints for 
# # Windows and Linux AD instances deployed in AWS. It also retrieves the ALB DNS name.
# #
# # REQUIREMENTS:
# #   - AWS CLI installed and configured with credentials/permissions.
# #   - Instances must be tagged with:
# #       * Name = windows-ad-instance
# #       * Name = efs-client-instance
# #   - ALB must be deployed with name "rstudio-alb"
# # --------------------------------------------------------------------------------------------------

# # --------------------------------------------------------------------------------------------------
# # Configuration
# # --------------------------------------------------------------------------------------------------
# AWS_DEFAULT_REGION="us-east-1"   # AWS region where instances are deployed

# # --------------------------------------------------------------------------------------------------
# # Lookup Windows AD Instance
# # --------------------------------------------------------------------------------------------------
# windows_dns=$(aws ec2 describe-instances \
#   --filters "Name=tag:Name,Values=windows-ad-admin" \
#   --query 'Reservations[].Instances[].PublicDnsName' \
#   --output text)

# if [ -z "$windows_dns" ]; then
#   echo "WARNING: No Windows AD instance found with tag Name=windows-ad-admin"
# else
#   echo "NOTE: Windows Instance FQDN:       $(echo $windows_dns | xargs)"
# fi

# # --------------------------------------------------------------------------------------------------
# # Lookup Linux AD Instance
# # --------------------------------------------------------------------------------------------------
# linux_dns=$(aws ec2 describe-instances \
#   --filters "Name=tag:Name,Values=efs-samba-gateway" \
#   --query 'Reservations[].Instances[].PrivateDnsName' \
#   --output text)

# if [ -z "$linux_dns" ]; then
#   echo "WARNING: No EFS Gateway instance found with tag Name=efs-samba-gateway"
# else
#   echo "NOTE: EFS Gateway Instance FQDN:   $(echo $linux_dns | xargs)"
# fi

# # --------------------------------------------------------------------------------------------------
# # Lookup ALB DNS Name
# # --------------------------------------------------------------------------------------------------
# alb_dns=$(aws elbv2 describe-load-balancers \
#   --names rstudio-alb \
#   --query 'LoadBalancers[0].DNSName' \
#   --output text)

# if [ -z "$alb_dns" ]; then
#   echo "WARNING: No ALB found with name rstudio-alb"
# else
#   echo "NOTE: RStudio ALB Endpoint:        http://$alb_dns"
# fi
