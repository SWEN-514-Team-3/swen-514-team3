variable "name" {
  description = "Project resource name prefix."
  type        = string
}

variable "vpc_cidr" {
  description = "Application VPC CIDR."
  type        = string
  default     = "10.20.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "Two private subnet CIDRs, placed in distinct availability zones."
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24"]
  validation {
    condition     = length(var.private_subnet_cidrs) == 2
    error_message = "Provide exactly two private subnet CIDRs."
  }
}
