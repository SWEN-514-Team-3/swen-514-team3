output "bucket_name" {
  description = "Name of the S3 bucket hosting the frontend."
  value       = aws_s3_bucket.site.bucket
}

output "website_url" {
  description = "Public S3 static-website endpoint for the frontend."
  value       = "http://${aws_s3_bucket_website_configuration.site.website_endpoint}"
}
