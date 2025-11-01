#!/bin/bash
# ==============================================================================
# RStudio Server Container Startup Script
# ------------------------------------------------------------------------------

# This script initializes an RStudio Server container that authenticates
# against Active Directory via SSSD. It:
#   1. Starts a DBus daemon (required by `realm` and `sssd`).
#   2. Retrieves domain join credentials securely from AWS Secrets Manager.
#   3. Joins the Active Directory domain using `realm`.
#   4. Adjusts SSSD configuration for simpler user naming and consistent IDs.
#   5. Prepares default user skeletons to avoid permission warnings.
#   6. Starts RStudio Server in the foreground for container-based execution.

# ==============================================================================

# ------------------------------------------------------------------------------
# Configuration Variables
# ------------------------------------------------------------------------------

echo "NOTE: Starting RStudio Server container initialization..."
echo "NOTE: Reading K8S secret values..."

admin_secret=$(cat /etc/rstudio-config/admin_secret)
domain_fqdn=$(cat /etc/rstudio-config/domain_fqdn)
region=$(cat /etc/rstudio-config/region)    
export AWS_DEFAULT_REGION="${region}"

# ------------------------------------------------------------------------------
# Initialize System Services
# ------------------------------------------------------------------------------

# `realm` and `sssd` require DBus. In a container, DBus is not typically active,
# so this command starts a minimal system instance in the background.
dbus-daemon --system --fork

# ------------------------------------------------------------------------------
# Retrieve AD Credentials from AWS Secrets Manager
# ------------------------------------------------------------------------------

# The secret is expected to contain a JSON payload like:
#   { "username": "MCLOUD\\Admin", "password": "SuperSecurePass123" }

echo "NOTE: Retrieving AD join credentials from Secrets Manager..."

secretValue=$(aws secretsmanager get-secret-value \
    --secret-id "${admin_secret}" \
    --query SecretString --output text)

# Extract credentials safely using `jq`
admin_password=$(echo "${secretValue}" | jq -r '.password')
admin_username=$(echo "${secretValue}" | jq -r '.username' | sed 's/.*\\//')

# ------------------------------------------------------------------------------
# Join Active Directory Domain
# ------------------------------------------------------------------------------

echo "NOTE: Joining Active Directory domain: ${domain_fqdn}..."

# Pipe the admin password into `realm join` for noninteractive authentication.
# The join process registers this container as a domain member and configures
# SSSD to use AD as its identity source.
# All output is logged for troubleshooting.
echo -e "${admin_password}" | sudo /usr/sbin/realm join \
    -U "${admin_username}" \
    "${domain_fqdn}" \
    --verbose \
    >> /root/join.log 2>> /root/join.log

echo "NOTE: Successfully joined domain: ${domain_fqdn}"
realm list

# ------------------------------------------------------------------------------
# SSSD Configuration Adjustments
# ------------------------------------------------------------------------------

# By default, SSSD may require fully-qualified usernames (user@domain)
# and auto-generate UIDs/GIDs. The following edits make usernames shorter
# and respect the IDs defined in AD.

echo "NOTE: Adjusting SSSD configuration..."

sudo sed -i 's/use_fully_qualified_names = True/use_fully_qualified_names = False/g' \
    /etc/sssd/sssd.conf
sudo sed -i 's/ldap_id_mapping = True/ldap_id_mapping = False/g' \
    /etc/sssd/sssd.conf
sudo sed -i 's|fallback_homedir = /home/%u@%d|fallback_homedir = /home/%u|' \
    /etc/sssd/sssd.conf

# ------------------------------------------------------------------------------
# Default User Environment Setup
# ------------------------------------------------------------------------------

echo "NOTE: Preparing default user skeleton directory..."

# Prepare the default skeleton directory (`/etc/skel`) so new AD users
# have a consistent environment upon first login.

# Create a symbolic link to a shared directory (e.g., /efs) if applicable.
ln -s /efs /etc/skel/efs
sudo sed -i 's/^\(\s*HOME_MODE\s*\)[0-9]\+/\10700/' /etc/login.defs

# Pre-create an empty `.Xauthority` file to suppress warnings in RStudio
touch /etc/skel/.Xauthority
chmod 600 /etc/skel/.Xauthority

echo "NOTE: Starting SSSD service..."

# Restart SSSD to apply configuration changes and activate the domain join.
sudo systemctl restart sssd
sleep 5  # Allow some time for SSSD to stabilize

# ---------------------------------------------------------------------------------
# Configure R Library Paths to include /efs/rlibs
# ---------------------------------------------------------------------------------

echo "NOTE: Configuring R library paths..."

cat <<'EOF' | sudo tee /usr/lib/R/etc/Rprofile.site > /dev/null
local({
  userlib <- Sys.getenv("R_LIBS_USER")
  if (!dir.exists(userlib)) {
    dir.create(userlib, recursive = TRUE, showWarnings = FALSE)
  }
  efs <- "/efs/rlibs"
  .libPaths(c(userlib, efs, .libPaths()))
})
EOF

chgrp rstudio-admins /efs/rlibs
rm -f -r /home/rstudio 

# ------------------------------------------------------------------------------
# Launch RStudio Server
# ------------------------------------------------------------------------------

# Ensure the log directory and file exist for live log tailing.
touch /var/log/rstudio/rstudio-server/rserver.log

# Start RStudio Server in the foreground (non-daemonized) so it remains
# as the main container process.
# Logs are streamed to stdout for container monitoring.
echo "NOTE: Starting RStudio Server..."

/usr/lib/rstudio-server/bin/rserver --server-daemonize=0 &

# Stream logs continuously to container output

echo "NOTE: RStudio Server initialization complete. Tailing logs..."

tail -f /var/log/rstudio/rstudio-server/rserver.log
