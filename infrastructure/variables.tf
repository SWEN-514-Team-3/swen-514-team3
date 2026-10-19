variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Lowercase project name used as a prefix for resource names and the Project tag."
  type        = string
  default     = "meeting-momentum"
}

variable "frontend_bucket_name" {
  description = "Globally unique S3 bucket name. Change if already taken."
  type        = string
  default     = "meeting-momentum-frontend-930783431153"

}

variable "lambda_permissions_boundary_arn" {
  description = "Course-required IAM permissions boundary for the Lambda execution role, if applicable."
  type        = string
  default     = null
}

variable "reminder_email" {
  description = "Optional SNS reminder email; leave unset for initial deployment."
  type        = string
  default     = null
}
