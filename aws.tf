provider "aws" {
  region = "us-west-2"
}

terraform {
  backend "s3" {
    bucket = "axdd-aws-dev-terraform-2"
    key    = "infrastructure-development-example"
    region = "us-west-2"
    encrypt = "true"
  }
}

