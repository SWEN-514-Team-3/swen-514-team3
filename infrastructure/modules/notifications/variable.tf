variable "project_name" {
  description = "Project name used for reminder resources."
  type        = string
}

variable "reminder_email" {
  description = "Optional reminder email; SNS confirmation is required if supplied."
  type        = string
  default     = null
}
