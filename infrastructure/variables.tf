variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Lowercase project name used as a prefix for resource names and the Project tag."
  type        = string
  default     = "meeting-momentum"
  validation {
    condition     = can(regex("^[a-z][a-z0-9]*(-[a-z0-9]+)*$", var.project_name)) && length(var.project_name) <= 25
    error_message = "Use a lowercase project name starting with a letter, at most 25 characters, with single hyphens between words."
  }
}

variable "frontend_bucket_name" {
  description = "Optional exact frontend bucket name. Leave null to let Terraform generate a unique suffix."
  type        = string
  default     = null

}

variable "recordings_bucket_name" {
  description = "Optional exact recordings bucket name. Leave null to let Terraform generate a unique suffix."
  type        = string
  default     = null
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

variable "database_name" {
  description = "Initial PostgreSQL database name shared by RDS and application Lambdas."
  type        = string
  default     = "meetingmomentum"
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9]{0,62}$", var.database_name))
    error_message = "Database name must start with a letter and contain at most 63 alphanumeric characters."
  }
}
