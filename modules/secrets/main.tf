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

  # Enforce 30-day recovery window for production safety
  # Dev can use 7 days for faster iteration
  recovery_window_in_days = var.environment == "dev" ? 7 : 30

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
