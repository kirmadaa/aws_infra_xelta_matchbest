# backend.tf

terraform {
  backend "s3" {
    bucket         = "xeltastate"
    dynamodb_table = "xelta-terraform-locks"
    region         = "ap-south-1"
    encrypt        = true
    # The "key" is left out here because it will be provided by the command line.
  }
}