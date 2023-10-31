terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_s3_bucket" "web_app" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_website_configuration" "web_app_config" {
  bucket = aws_s3_bucket.web_app.bucket
  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "error.html"
  }
}