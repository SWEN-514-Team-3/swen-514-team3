terraform {
  # State bucket is created by hand (versioned, private) and is not managed here.
  # Credentials come from the environment (GitHub OIDC in CI), never this file.
  backend "s3" {
    bucket       = "swen514-team3-tfstate-calvinwin7"
    key          = "meeting-momentum/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # S3-native locking; requires Terraform >= 1.10
  }
}
