terraform {
  # Bucket, key, and region are supplied by the selected GitHub environment/workflow.
  backend "s3" {
    encrypt = true
  }
}
