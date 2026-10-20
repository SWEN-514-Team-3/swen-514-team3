variable "bucket_name" {
  description = "Optional exact name for the frontend S3 bucket; null enables generated naming."
  type        = string
  default     = null
}

variable "bucket_prefix" {
  description = "Prefix for Terraform-generated bucket names (at most 37 characters)."
  type        = string
  default     = "meeting-momentum-frontend-"
  validation {
    condition     = length(var.bucket_prefix) <= 37
    error_message = "The bucket prefix must be at most 37 characters to leave room for Terraform's suffix."
  }
}
