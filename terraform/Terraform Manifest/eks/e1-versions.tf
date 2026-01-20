terraform {
  # Required providers and version constraints
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
backend "s3" {
    bucket         = "my-terraform-state-bucket2-8718"         
    key            = "eks/dev/terraform.tfstate"            
    region         = "us-east-1"                            
    encrypt        = true                                   
    use_lockfile   = true     
  }

}

provider "aws" {
  # AWS region to use for all resources (from variables)
  region = var.aws_region
}