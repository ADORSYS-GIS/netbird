# NOTE: You must create this bucket manually or via a separate bootstrap script before running terraform init.
# Alternatively, comment this out for local state during initial development.
terraform {
  backend "gcs" {
    bucket  = "netbird" # Replace with your unique GCS bucket name
    prefix  = "terraform/state"
  }
}
