
# SNS topic that distributes action-item reminders
resource "aws_sns_topic" "action_item_reminders" {
  name = "${var.project_name}-action-item-reminders"
}


resource "aws_sns_topic_subscription" "reminder_email" {
  count     = var.reminder_email != null ? 1 : 0
  topic_arn = aws_sns_topic.action_item_reminders.arn
  protocol  = "email"
  endpoint  = var.reminder_email
}

# EventBridge Scheduler execution role
resource "aws_iam_role" "scheduler_sns_role" {
  name = "${var.project_name}-scheduler-sns-role"

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

# Allow Scheduler to publish to the reminder topic
resource "aws_iam_role_policy" "scheduler_sns_publish" {
  name = "${var.project_name}-scheduler-sns-publish"
  role = aws_iam_role.scheduler_sns_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sns:Publish"]
      Resource = aws_sns_topic.action_item_reminders.arn
    }]
  })
}

output "reminder_sns_topic_arn" {
  description = "SNS topic ARN for action-item reminders"
  value       = aws_sns_topic.action_item_reminders.arn
}

output "scheduler_sns_role_arn" {
  description = "IAM role ARN for EventBridge Scheduler targets"
  value       = aws_iam_role.scheduler_sns_role.arn
}
