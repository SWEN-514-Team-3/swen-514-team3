output "execution_role_arn" {
  value = aws_iam_role.execution.arn
}

output "function_name" {
  value = aws_lambda_function.test.function_name
}
