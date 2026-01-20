terraform {
  backend "s3" {
    bucket = "my-terraform-state-bucket2-8718"
    key    = "ec2/terraform.tfstate"
    region = "us-east-1"
  }
}