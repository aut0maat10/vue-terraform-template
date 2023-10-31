terraform {
    backend "s3" {
        bucket = var.backend_bucket
        key    = "tf-backend.tfstate"
        region = var.region
        encrypt = true
        dynamodb_table = "vue-tf-terraform-backend"
  }
}
