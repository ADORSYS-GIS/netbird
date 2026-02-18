terraform {
  backend "s3" {
    bucket         = "netbird-terraform-state"
    key            = "helm-stack/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
