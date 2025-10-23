#!/bin/bash
# --------------------------------------------------------------------------------------------------
# Description:
# This script queries AWS EC2 for instances tagged with specific names and outputs their
# associated public DNS names. It is primarily used to quickly locate endpoints for 
# Windows and Linux AD instances deployed in AWS. It also retrieves the ALB DNS name.
#
# REQUIREMENTS:
#   - AWS CLI installed and configured with credentials/permissions.
#   - Instances must be tagged with:
#       * Name = windows-ad-instance
#       * Name = efs-client-instance
#   - ALB must be deployed with name "rstudio-alb"
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------------------------------
AWS_DEFAULT_REGION="us-east-1"   # AWS region where instances are deployed

# --------------------------------------------------------------------------------------------------
# Lookup Windows AD Instance
# --------------------------------------------------------------------------------------------------
windows_dns=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=windows-ad-admin" \
  --query 'Reservations[].Instances[].PublicDnsName' \
  --output text)

if [ -z "$windows_dns" ]; then
  echo "WARNING: No Windows AD instance found with tag Name=windows-ad-admin"
else
  echo "NOTE: Windows Instance FQDN:       $(echo $windows_dns | xargs)"
fi

# --------------------------------------------------------------------------------------------------
# Lookup Linux AD Instance
# --------------------------------------------------------------------------------------------------
linux_dns=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=efs-samba-gateway" \
  --query 'Reservations[].Instances[].PrivateDnsName' \
  --output text)

if [ -z "$linux_dns" ]; then
  echo "WARNING: No EFS Gateway instance found with tag Name=efs-samba-gateway"
else
  echo "NOTE: EFS Gateway Instance FQDN:   $(echo $linux_dns | xargs)"
fi

# --------------------------------------------------------------------------------------------------
# Lookup ALB DNS Name
# --------------------------------------------------------------------------------------------------
alb_dns=$(aws elbv2 describe-load-balancers \
  --names rstudio-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

if [ -z "$alb_dns" ]; then
  echo "WARNING: No ALB found with name rstudio-alb"
else
  echo "NOTE: RStudio ALB Endpoint:        http://$alb_dns"
fi
