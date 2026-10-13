variable "name" {
  description = "Prefix for the bucket name. A random suffix is appended to make it globally unique."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,45}$", var.name))
    error_message = "name must be lowercase letters, numbers and hyphens (max 46 chars) to form a valid S3 bucket name."
  }
}

variable "source_dir" {
  description = "Directory containing the static site files. Pass it from the root as \"$${path.root}/...\"."
  type        = string
}

variable "files" {
  description = "Files (relative to source_dir) to upload to the bucket."
  type        = list(string)
  default     = ["index.html", "styles.css", "main.js"]
}

variable "index_document" {
  description = "Index document served at the website root."
  type        = string
  default     = "index.html"
}

variable "tags" {
  description = "Extra tags applied to the bucket."
  type        = map(string)
  default     = {}
}
