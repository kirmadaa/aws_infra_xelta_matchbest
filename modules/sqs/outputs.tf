output "jobs_queue_arn" {
  description = "ARN of the main jobs SQS queue"
  value       = aws_sqs_queue.jobs.arn
}

output "jobs_queue_url" {
  description = "URL of the main jobs SQS queue"
  value       = aws_sqs_queue.jobs.id
}
