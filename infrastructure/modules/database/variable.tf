variable "name" {
  description = "Prefix for resource names."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets supplied by the networking module."
  type        = list(string)
}

variable "security_group_id" {
  description = "Database security group supplied by the networking module."
  type        = string
}
