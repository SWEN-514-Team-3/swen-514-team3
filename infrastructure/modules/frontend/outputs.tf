output "bucket_name" {
  value = aws_s3_bucket.site.bucket
}
output "website_url" {
  description = "HTTPS CloudFront URL for the S3-hosted frontend."
  value       = "https://${aws_cloudfront_distribution.site.domain_name}"
}
