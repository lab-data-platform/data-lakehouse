output "name" {
  description = "Nome do bucket."
  value       = aws_s3_bucket.this.bucket
}

output "arn" {
  description = "ARN do bucket."
  value       = aws_s3_bucket.this.arn
}

output "versioning_enabled" {
  description = "Indica se o versionamento está ligado."
  value       = length(aws_s3_bucket_versioning.this) == 1
}
