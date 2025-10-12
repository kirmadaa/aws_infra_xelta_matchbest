# modules/secrets/main.tf

# Generate random password for database
resource "random_password" "db_password" {
  length  = 32
  special = true
}

# Database Credentials Secret
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "xelta-${var.environment}-db-credentials"
  description = "Database credentials for xelta ${var.environment}"

  # FIXED: Set recovery window to 0 to allow immediate deletion and recreation
  recovery_window_in_days = 0

  # Add lifecycle to prevent accidental deletion in production
  lifecycle {
    create_before_destroy = false
    ignore_changes        = []
  }

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
