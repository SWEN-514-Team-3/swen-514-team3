variable "name" {
  type        = string
  description = "Project resource name prefix."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnets for Lambda network interfaces."
}

variable "security_group_id" {
  type        = string
  description = "Lambda security group."
}

variable "permissions_boundary_arn" {
  type        = string
  description = "Course-required IAM permissions boundary, if applicable."
  default     = null
}
