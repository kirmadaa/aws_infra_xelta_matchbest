output "bucket_arn" {
  description = "ARN of the outputs S3 bucket"
  value       = aws_s3_bucket.outputs.arn
}

output "bucket_id" {
  description = "ID (name) of the outputs S3 bucket"
  value       = aws_s3_bucket.outputs.id
}
