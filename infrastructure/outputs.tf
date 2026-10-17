output "frontend_bucket_name" {
  description = "S3 bucket hosting the frontend."
  value       = module.frontend.bucket_name
}

output "frontend_website_url" {
  description = "Public URL of the frontend."
  value       = module.frontend.website_url
}

output "db_endpoint" {
  description = "Hostname of the database."
  value       = module.database.db_endpoint
}

output "db_secret_arn" {
  description = "Secrets Manager secret holding the database login."
  value       = module.database.db_secret_arn
}

output "api_url" {
  description = "HTTP API Gateway endpoint."
  value       = aws_apigatewayv2_api.http.api_endpoint
}
