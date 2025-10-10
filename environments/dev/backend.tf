terraform {
  backend "s3" {
    bucket         = "xeltainfrastate"
    key            = "xelta-dev/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "xelta-terraform-locks"
  }
}
