module "frontend" {
  source = "./modules/frontend"
}

module "database" {
  source = "./modules/database"
  name   = "meeting-momentum"
}

resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-api-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Allow Lambda to read the database credentials from Secrets Manager
resource "aws_iam_role_policy" "lambda_db_secret" {
  name = "${var.project_name}-db-secret-access"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = module.database.db_secret_arn
    }]
  })
}

# API Lambda
resource "aws_lambda_function" "api" {
  function_name = "${var.project_name}-api"
  role          = aws_iam_role.lambda.arn
  runtime       = "python3.12"
  handler       = "handler.lambda_handler"

  filename         = "${path.module}/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda.zip")

  timeout     = 15
  memory_size = 256

  # Required for access to the private PostgreSQL database
  vpc_config {
    subnet_ids         = module.database.subnet_ids
    security_group_ids = [module.database.lambda_security_group_id]
  }

  environment {
    variables = {
      DB_HOST       = module.database.db_endpoint
      DB_NAME       = "meetingmomentum"
      DB_SECRET_ARN = module.database.db_secret_arn
      AWS_REGION    = var.aws_region
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_iam_role_policy.lambda_db_secret
  ]
}

# HTTP API Gateway
resource "aws_apigatewayv2_api" "http" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = [
      "http://${module.frontend.website_url}"
    ]
    allow_methods = [
      "GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"
    ]
    allow_headers = [
      "Content-Type", "Authorization"
    ]
    max_age = 300
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# Health-check route
resource "aws_apigatewayv2_route" "health" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Meeting routes
resource "aws_apigatewayv2_route" "meetings" {
  for_each = toset([
    "GET /meetings",
    "POST /meetings",
    "GET /meetings/{id}",
    "PUT /meetings/{id}",
    "DELETE /meetings/{id}"
  ])

  api_id    = aws_apigatewayv2_api.http.id
  route_key = each.value
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowHttpApiInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}






