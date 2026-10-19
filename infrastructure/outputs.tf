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
output "lambda_execution_role_arn" {
  value = module.lambda_test.execution_role_arn
}
output "network_test_function_name" {
  value = module.lambda_test.function_name
}

output "cognito_pool_id" { value = module.authentication.pool_id }

output "cognito_client_id" { value = module.authentication.client_id }

output "cognito_domain" { value = module.authentication.domain }
