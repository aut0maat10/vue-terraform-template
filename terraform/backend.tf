terraform {
    backend "s3" {
        bucket = "vue-tf-terraform-backend"
        key    = "tf-backend.tfstate"
        region = "us-east-1"
        encrypt = true
        dynamodb_table = "vue-tf-terraform-backend"
  }
}
