# Generate random password for database
resource "random_password" "db_password" {
  length  = 32
  special = true
}

# Database Credentials Secret
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "xelta-${var.environment}-db-credentials"
  description = "Database credentials for xelta ${var.environment}"
  kms_key_id  = var.kms_key_id

  recovery_window_in_days = 7

  tags = {
    Name        = "xelta-${var.environment}-db-credentials"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    username = "xeltaadmin"
    password = random_password.db_password.result
  })
}

# Application Secrets (API keys, etc.)
resource "aws_secretsmanager_secret" "app_secrets" {
  name        = "xelta-${var.environment}-app-secrets"
  description = "Application secrets for xelta ${var.environment}"
  kms_key_id  = var.kms_key_id

  recovery_window_in_days = 7

  tags = {
    Name        = "xelta-${var.environment}-app-secrets"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = aws_secretsmanager_secret.app_secrets.id

  secret_string = jsonencode({
    jwt_secret      = "REPLACE_WITH_ACTUAL_JWT_SECRET"
    api_key         = "REPLACE_WITH_ACTUAL_API_KEY"
    encryption_key  = "REPLACE_WITH_ACTUAL_ENCRYPTION_KEY"
  })

  lifecycle {
    ignore_changes = [secret_string] # Prevent overwrite after manual update
  }
}