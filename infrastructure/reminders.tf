# Reminders: EventBridge Scheduler runs the API Lambda once a day. The Lambda
# finds action items that are overdue or due soon and publishes them to SNS.

# The Lambda sits in private subnets with no internet access, so SNS is
# reached through a VPC endpoint (same pattern as Secrets Manager and Bedrock).
resource "aws_security_group" "sns_endpoint" {
  name        = "${var.project_name}-sns-endpoint"
  description = "SNS HTTPS from application Lambda only"
  vpc_id      = module.networking.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "sns_https" {
  security_group_id            = aws_security_group.sns_endpoint.id
  referenced_security_group_id = module.networking.lambda_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

resource "aws_vpc_security_group_egress_rule" "lambda_sns" {
  security_group_id            = module.networking.lambda_security_group_id
  referenced_security_group_id = aws_security_group.sns_endpoint.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

resource "aws_vpc_endpoint" "sns" {
  vpc_id              = module.networking.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.sns"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = module.networking.private_subnet_ids
  security_group_ids  = [aws_security_group.sns_endpoint.id]
}

# Allow the Lambda to publish to the reminder topic
resource "aws_iam_role_policy" "lambda_sns_publish" {
  name = "${var.project_name}-sns-publish"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sns:Publish", "sns:ListSubscriptionsByTopic", "sns:GetSubscriptionAttributes"]
      Resource = module.notifications.reminder_sns_topic_arn
    }]
  })
}

# Allow EventBridge Scheduler to run the Lambda
resource "aws_iam_role" "reminder_scheduler" {
  name = "${var.project_name}-reminder-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "scheduler.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "reminder_scheduler_invoke" {
  name = "${var.project_name}-reminder-scheduler-invoke"
  role = aws_iam_role.reminder_scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction"]
      Resource = aws_lambda_function.api.arn
    }]
  })
}

# Every day at 13:00 UTC
resource "aws_scheduler_schedule" "daily_reminders" {
  name                = "${var.project_name}-daily-reminders"
  schedule_expression = "cron(0 13 * * ? *)"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.api.arn
    role_arn = aws_iam_role.reminder_scheduler.arn
    input    = jsonencode({ source = "reminder-schedule" })
  }
}
