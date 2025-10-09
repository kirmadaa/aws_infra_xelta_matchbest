terraform {
  backend "s3" {
    bucket         = "xeltainfrastatefiles"
    key            = "xelta-dev/terraform.tfstate"
    region         = "eu-west-3"
    encrypt        = true
    dynamodb_table = "xelta-terraform-locks"
  }
}
