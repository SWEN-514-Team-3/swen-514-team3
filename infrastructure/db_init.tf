# One-time database setup. The Setup workflow invokes this Lambda after apply
# to create the tables (schema.sql) and load the sample data (seed.sql).
# It runs in the VPC because the database is private.
#
# The package is built by lambda/db_init/build.sh. Run that script first if you
# run terraform on your own machine.
data "archive_file" "db_init" {
  type        = "zip"
  source_dir  = "${path.module}/../build/db_init"
  output_path = "${path.module}/.terraform/db-init-lambda.zip"
}

resource "aws_lambda_function" "db_init" {
  function_name    = "${var.project_name}-db-init"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.db_init.output_path
  source_code_hash = data.archive_file.db_init.output_base64sha256
  timeout          = 120
  memory_size      = 256

  vpc_config {
    subnet_ids         = module.database.subnet_ids
    security_group_ids = [module.networking.lambda_security_group_id]
  }

  environment {
    variables = {
      DB_HOST = module.database.db_endpoint
      DB_NAME = "meetingmomentum"
    }
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_logs]
}

output "db_init_function_name" {
  description = "Lambda that applies schema.sql and seed.sql."
  value       = aws_lambda_function.db_init.function_name
}
