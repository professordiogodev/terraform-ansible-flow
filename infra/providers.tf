terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # Restricts updates to minor versions only
    }
  }
}

provider "aws" {
  region = "us-west-2" #To avoid the heavy traffic as other students are doing a lot of labs in the meanwhile
}