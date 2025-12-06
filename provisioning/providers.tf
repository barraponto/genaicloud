terraform {
  required_providers {
    google = {
      source  = "registry.opentofu.org/hashicorp/google"
      version = "~> 7.11.0"  # Example version, use the version suitable for your case
    }
  }
}

provider "google" {
  project = "boardgame-fm"
  region  = "us-central1"
  # Add any other required provider arguments here
}
