output "recordings_bucket_name" {
  description = "S3 bucket storing meeting recordings and transcripts."
  value       = aws_s3_bucket.recordings_bucket.bucket
}

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
output "vpc_id" {
  value = module.networking.vpc_id
}
output "private_subnet_ids" {
  value = module.networking.private_subnet_ids
}
output "lambda_security_group_id" {
  value = module.networking.lambda_security_group_id
}
output "database_security_group_id" {
  value = module.networking.database_security_group_id
}

output "cognito_pool_id" { value = module.authentication.pool_id }

output "cognito_client_id" { value = module.authentication.client_id }

output "cognito_domain" { value = module.authentication.domain }

output "reminder_sns_topic_arn" {
  value = module.notifications.reminder_sns_topic_arn
}
