# ===================================================================
# RANDOM PASSWORD: Active Directory Administrator
# -------------------------------------------------------------------
# Generates a secure, random 24-character password for the AD
# Administrator account. The password includes limited special
# characters (underscore and period) for compatibility with
# Windows domain password policies.
# ===================================================================
resource "random_password" "admin_password" {
  length           = 24
  special          = true
  override_special = "_."
}

# ===================================================================
# SECRET: Active Directory Administrator Credentials
# -------------------------------------------------------------------
# Creates an AWS Secrets Manager secret to securely store the
# Administrator credentials for the Active Directory domain.
#
# This entry is versioned automatically when credentials are
# updated, ensuring full traceability and audit compliance.
# ===================================================================
resource "aws_secretsmanager_secret" "admin_secret" {
  name        = "admin_ad_credentials"
  description = "AD Administrator Credentials"

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_secretsmanager_secret_version" "admin_secret_version" {
  secret_id = aws_secretsmanager_secret.admin_secret.id
  secret_string = jsonencode({
    username = "${var.netbios}\\Admin"
    password = random_password.admin_password.result
  })
}

# ===================================================================
# RANDOM PASSWORD: John Smith
# -------------------------------------------------------------------
# Generates a secure, random 24-character password for the
# "jsmith" Active Directory account.
# ===================================================================
resource "random_password" "jsmith_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

# ===================================================================
# SECRET: John Smith AD Credentials
# -------------------------------------------------------------------
# Stores John Smith’s Active Directory username and password
# in AWS Secrets Manager for secure retrieval and rotation.
# ===================================================================
resource "aws_secretsmanager_secret" "jsmith_secret" {
  name        = "jsmith_ad_credentials"
  description = "John Smith's AD Credentials"

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_secretsmanager_secret_version" "jsmith_secret_version" {
  secret_id = aws_secretsmanager_secret.jsmith_secret.id
  secret_string = jsonencode({
    username = "${var.netbios}\\jsmith"
    password = random_password.jsmith_password.result
  })
}

# ===================================================================
# RANDOM PASSWORD: Emily Davis
# -------------------------------------------------------------------
# Generates a secure 24-character password for the "edavis"
# Active Directory account, including limited special characters.
# ===================================================================
resource "random_password" "edavis_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

# ===================================================================
# SECRET: Emily Davis AD Credentials
# -------------------------------------------------------------------
# Creates and stores Emily Davis’s credentials in AWS Secrets
# Manager. The secret is versioned for future password rotation.
# ===================================================================
resource "aws_secretsmanager_secret" "edavis_secret" {
  name        = "edavis_ad_credentials"
  description = "Emily Davis's AD Credentials"

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_secretsmanager_secret_version" "edavis_secret_version" {
  secret_id = aws_secretsmanager_secret.edavis_secret.id
  secret_string = jsonencode({
    username = "${var.netbios}\\edavis"
    password = random_password.edavis_password.result
  })
}

# ===================================================================
# RANDOM PASSWORD: Raj Patel
# -------------------------------------------------------------------
# Generates a secure 24-character password for the "rpatel"
# Active Directory account.
# ===================================================================
resource "random_password" "rpatel_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

# ===================================================================
# SECRET: Raj Patel AD Credentials
# -------------------------------------------------------------------
# Creates a versioned secret for Raj Patel’s AD credentials
# and stores it securely in AWS Secrets Manager.
# ===================================================================
resource "aws_secretsmanager_secret" "rpatel_secret" {
  name        = "rpatel_ad_credentials"
  description = "Raj Patel's AD Credentials"

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_secretsmanager_secret_version" "rpatel_secret_version" {
  secret_id = aws_secretsmanager_secret.rpatel_secret.id
  secret_string = jsonencode({
    username = "${var.netbios}\\rpatel"
    password = random_password.rpatel_password.result
  })
}

# ===================================================================
# RANDOM PASSWORD: Amit Kumar
# -------------------------------------------------------------------
# Generates a secure 24-character password for the "akumar"
# Active Directory account.
# ===================================================================
resource "random_password" "akumar_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

# ===================================================================
# SECRET: Amit Kumar AD Credentials
# -------------------------------------------------------------------
# Creates a Secrets Manager entry for Amit Kumar’s credentials
# and manages password rotation via versioning.
# ===================================================================
resource "aws_secretsmanager_secret" "akumar_secret" {
  name        = "akumar_ad_credentials"
  description = "Amit Kumar's AD Credentials"

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_secretsmanager_secret_version" "akumar_secret_version" {
  secret_id = aws_secretsmanager_secret.akumar_secret.id
  secret_string = jsonencode({
    username = "${var.netbios}\\akumar"
    password = random_password.akumar_password.result
  })
}

# ===================================================================
# RANDOM PASSWORD: RStudio Service Account
# -------------------------------------------------------------------
# Generates a random 24-character alphanumeric password for the
# "rstudio" service account used by RStudio Server or related
# automation components.
# ===================================================================
resource "random_password" "rstudio_password" {
  length           = 24
  special          = false
}

# ===================================================================
# SECRET: RStudio Service Account Credentials
# -------------------------------------------------------------------
# Creates an AWS Secrets Manager entry for the RStudio account
# and stores the username/password pair securely for downstream
# use (e.g., automated service logins or provisioning scripts).
# ===================================================================
resource "aws_secretsmanager_secret" "rstudio_secret" {
  name        = "rstudio_ad_credentials"
  description = "RStudio Service Account Credentials"

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_secretsmanager_secret_version" "rstudio_secret_version" {
  secret_id = aws_secretsmanager_secret.rstudio_secret.id
  secret_string = jsonencode({
    username = "${var.netbios}\\rstudio"
    password = random_password.rstudio_password.result
  })
}
