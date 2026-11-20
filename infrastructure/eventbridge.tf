resource "aws_iam_role_policy" "broadcast_sns_publish" {
  name = "${var.project_name}-broadcast-sns-publish"
  role = aws_iam_role.broadcast_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sns:Publish", "sns:Subscribe", "sns:ListSubscriptionsByTopic", "sns:GetSubscriptionAttributes"]
      Resource = module.notifications.reminder_sns_topic_arn
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

resource "aws_iam_role_policy_attachment" "broadcast_lambda_logs" {
  role       = aws_iam_role.broadcast_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
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
        Resource = module.notifications.scheduler_sns_role_arn
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
      RECAP_EVENT_SOURCE     = "${var.project_name}.app"
      REMINDER_SNS_TOPIC_ARN = module.notifications.reminder_sns_topic_arn
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

# API Gateway v2 Route
resource "aws_apigatewayv2_route" "broadcast" {
  api_id               = aws_apigatewayv2_api.http.id
  route_key            = "POST /broadcast"
  target               = "integrations/${aws_apigatewayv2_integration.broadcast_lambda.id}"
  authorization_type   = "JWT"
  authorizer_id        = aws_apigatewayv2_authorizer.cognito.id
  authorization_scopes = ["openid"]
}

# Permission for API Gateway HTTP API to invoke broadcast Lambda
resource "aws_lambda_permission" "apigw_broadcast" {
  statement_id  = "AllowAPIGatewayInvokeBroadcast"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.broadcast.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

resource "aws_iam_role_policy" "broadcast_eventbridge_put" {
  name = "${var.project_name}-broadcast-eventbridge-put"
  role = aws_iam_role.broadcast_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["events:PutEvents"]
      Resource = "arn:aws:events:*:*:event-bus/default"
    }]
  })
}

resource "aws_cloudwatch_event_rule" "meeting_recap_rule" {
  name        = "${var.project_name}-meeting-recap-rule"
  description = "Routes generated meeting recaps to the broadcast Lambda"

  event_pattern = jsonencode({
    source      = ["${var.project_name}.app"]
    detail-type = ["GeneratedMeetingRecap"]
  })
}

resource "aws_cloudwatch_event_target" "broadcast_recap_target" {
  rule      = aws_cloudwatch_event_rule.meeting_recap_rule.name
  target_id = "TriggerBroadcastLambda"
  arn       = aws_lambda_function.broadcast.arn
}

resource "aws_lambda_permission" "eventbridge_broadcast" {
  statement_id  = "AllowEventBridgeInvokeBroadcast"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.broadcast.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.meeting_recap_rule.arn
}