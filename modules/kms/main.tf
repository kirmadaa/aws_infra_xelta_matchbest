# KMS Key for encryption
resource "aws_kms_key" "main" {
  description             = "KMS key for xelta ${var.environment} encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name        = "xelta-${var.environment}-kms"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "main" {
  name          = "alias/xelta-${var.environment}"
  target_key_id = aws_kms_key.main.key_id
}