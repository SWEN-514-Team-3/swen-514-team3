resource "aws_scheduler_schedule" "action_item_reminder_schedule" {
  name       = "${var.project_name}-action-item-reminder-schedule"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "None"

  target {
    arn      = aws_sns_topic.action_item_reminders.arn
    role_arn = aws_iam_role.scheduler_sns_role.arn
  }
}

resource "aws_iam_role_policy" "broadcast_sns_publish" {
  name = "${var.project_name}-broadcast-sns-publish"
  role = aws_iam_role.broadcast_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sns:Publish", "sns:Subscribe"]
      Resource = aws_sns_topic.action_item_reminders.arn
    }]
  })
}

resource "aws_iam_role" "broadcast_lambda_role" {
  name = "${var.project_name}-broadcast-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "api_lambda_scheduler" {
  name = "${var.project_name}-api-lambda-scheduler"
  role = aws_iam_role.broadcast_lambda_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "scheduler:CreateSchedule",
          "scheduler:UpdateSchedule",
          "scheduler:DeleteSchedule",
          "scheduler:GetSchedule"
        ]
        Resource = "arn:aws:scheduler:*:*:schedule/default/${var.project_name}-*"
      },
      {
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = aws_iam_role.scheduler_sns_role.arn
      }
    ]
  })
}

resource "aws_lambda_function" "broadcast" {
  function_name = "${var.project_name}-broadcast"
  role          = aws_iam_role.broadcast_lambda_role.arn
  runtime       = "python3.12"
  handler       = "handler.handle_broadcast"

  filename         = data.archive_file.api.output_path
  source_code_hash = data.archive_file.api.output_base64sha256

  timeout = 15

  environment {
    variables = {
      REMINDER_SNS_TOPIC_ARN = aws_sns_topic.action_item_reminders.arn
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.broadcast_lambda_logs,
    aws_iam_role_policy.broadcast_sns_publish
  ]
}

resource "aws_apigatewayv2_integration" "broadcast_lambda" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.broadcast.invoke_arn
  payload_format_version = "2.0"
}

# 3. API Gateway v2 Route (matching your POST /transcribe route)
resource "aws_apigatewayv2_route" "broadcast" {
  api_id               = aws_apigatewayv2_api.http.id
  route_key            = "POST /broadcast"
  target               = "integrations/${aws_apigatewayv2_integration.broadcast_lambda.id}"
  authorization_type   = "JWT"
  authorizer_id        = aws_apigatewayv2_authorizer.cognito.id
  authorization_scopes = ["openid"]
}

# 4. Permission for API Gateway HTTP API to invoke broadcast Lambda
resource "aws_lambda_permission" "apigw_broadcast" {
  statement_id  = "AllowAPIGatewayInvokeBroadcast"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.broadcast.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}