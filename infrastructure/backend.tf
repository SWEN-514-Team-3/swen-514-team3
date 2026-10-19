  terraform {
    # keep state in s3 so every workflow run shares it
    backend "s3" {
      bucket  = "swen514-team3-tfstate-calvinwin7"
      key     = "meeting-momentum/terraform.tfstate"
      region  = "us-east-1"
      encrypt = true
    }
  }
