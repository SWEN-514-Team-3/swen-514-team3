terraform {
  # Selected GitHub environment supplies bucket, key, and region during init.
  backend "s3" {
    encrypt = true
  }
}
