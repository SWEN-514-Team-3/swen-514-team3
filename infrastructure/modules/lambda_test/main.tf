data "aws_partition" "current" {}

resource "aws_iam_role" "execution" {
  name                 = "${var.name}-lambda-execution"
  permissions_boundary = var.permissions_boundary_arn
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "vpc_execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_cloudwatch_log_group" "test" {
  name              = "/aws/lambda/${var.name}-network-test"
  retention_in_days = 7
}

data "archive_file" "test" {
  type        = "zip"
  source_file = "${path.module}/handler.py"
  output_path = "${path.root}/.terraform/network-test.zip"
}

resource "aws_lambda_function" "test" {
  function_name    = "${var.name}-network-test"
  role             = aws_iam_role.execution.arn
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.test.output_path
  source_code_hash = data.archive_file.test.output_base64sha256
  timeout          = 10
  memory_size      = 128

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.vpc_execution,
    aws_cloudwatch_log_group.test
  ]
}
