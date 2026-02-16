terraform {
  backend "gcs" {
    bucket = "observe-472521-terraform-state"
    prefix = "netbird-infrastructure"
  }
}
