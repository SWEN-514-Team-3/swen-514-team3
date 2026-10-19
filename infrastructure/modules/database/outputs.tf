output "db_endpoint" {
  description = "Hostname of the database."
  value       = aws_db_instance.main.address
}

output "db_secret_arn" {
  description = "Secrets Manager secret holding the database login."
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}
  
output "lambda_security_group_id" {
  description = "Security group to attach to Lambdas that use the database."
  value       = aws_security_group.lambda_sg.id
}

output "subnet_ids" {
  description = "Subnets the database lives in."
  value       = var.subnet_ids
}
