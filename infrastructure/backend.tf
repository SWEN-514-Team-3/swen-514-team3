terraform {
  # Store the Terraform state in S3 so every workflow run uses the same state.
  # The state bucket was created by hand in the AWS Console.
  backend "s3" {
    bucket  = "swen514-team3-tfstate-calvinwin7"
    key     = "meeting-momentum/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
