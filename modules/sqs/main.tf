resource "aws_sqs_queue" "jobs" {
  name                        = "xelta-${var.environment}-jobs-queue"
  visibility_timeout_seconds  = 900
  message_retention_seconds   = 345600
  sqs_managed_sse_enabled     = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.jobs_dlq.arn
    maxReceiveCount     = 4
  })

  tags = {
    Name        = "xelta-${var.environment}-jobs-queue"
    Environment = var.environment
  }
}

resource "aws_sqs_queue" "jobs_dlq" {
  name                      = "xelta-${var.environment}-jobs-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true

  tags = {
    Name        = "xelta-${var.environment}-jobs-dlq"
    Environment = var.environment
  }
}
