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
