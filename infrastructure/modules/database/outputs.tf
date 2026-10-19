output "db_endpoint" {
  description = "Hostname of the database."
  value       = aws_db_instance.main.address
}

output "db_secret_arn" {
  description = "Secrets Manager secret holding the database login."
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}

output "subnet_ids" {
  description = "Subnets the database lives in."
  value       = var.subnet_ids
}
