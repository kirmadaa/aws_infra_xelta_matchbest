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

  # For production, use a recovery window. For dev, 0 is okay.
  recovery_window_in_days = var.environment == "prod" ? 7 : 0

  # Add this block to enable replication
  dynamic "replica" {
    for_each = toset(var.replica_regions)
    content {
      region = replica.value
    }
  }

  lifecycle {
    # This prevents accidental deletion in production
    prevent_destroy = var.environment == "prod"
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
