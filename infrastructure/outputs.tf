output "frontend_bucket_name" {
  description = "S3 bucket hosting the frontend."
  value       = module.frontend.bucket_name
}

output "frontend_website_url" {
  description = "Public URL of the frontend."
  value       = module.frontend.website_url
}
