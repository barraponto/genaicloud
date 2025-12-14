# This code is compatible with Terraform 4.25.0 and versions that are backwards compatible to 4.25.0.
# For information about validating this Terraform code, see https://developer.hashicorp.com/terraform/tutorials/gcp-get-started/google-cloud-platform-build#format-and-validate-the-configuration

variable "ssh_user" {
  description = "Username for SSH access"
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key_path" {
  description = "Path to your local SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = "default"  # Or your VPC name
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]
}

resource "google_compute_firewall" "allow_http_8080" {
  name    = "allow-http-8080"
  network = "default"  # Or your VPC name
  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ingress-http"]
}

resource "google_compute_address" "static_ip" {
  name         = "cluster-ip"
  region       = "us-central1"
  address_type = "EXTERNAL"
}

resource "google_compute_instance" "genai-cluster-1" {
  boot_disk {
    auto_delete = true
    device_name = "genai-cluster-1"

    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size  = 200
      type  = "pd-balanced"
    }

    mode = "READ_WRITE"
  }

  can_ip_forward      = true
  deletion_protection = false
  enable_display      = false

  labels = {
    goog-ec-src = "vm_add-tf"
  }

  machine_type = "e2-standard-4"
  name         = "genai-cluster-1"

  network_interface {
    access_config {
      network_tier = "PREMIUM"
      nat_ip       = google_compute_address.static_ip.address
    }

    queue_count = 0
    stack_type  = "IPV4_ONLY"
    subnetwork  = "projects/boardgame-fm/regions/us-central1/subnetworks/default"
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
    provisioning_model  = "STANDARD"
  }

  metadata = {
    # GCP alerts about this, but it doesn't really happen
    # startup-script = <<-EOF
    #   #!/bin/bash
    #   # Expand root filesystem to use full disk space
    #   growpart /dev/sda 1 || true
    #   resize2fs /dev/sda1 || true
    # EOF
    ssh-keys = "${var.ssh_user}:${file(var.ssh_public_key_path)}"
  }

  service_account {
    scopes = ["https://www.googleapis.com/auth/devstorage.read_only", "https://www.googleapis.com/auth/logging.write", "https://www.googleapis.com/auth/monitoring.write", "https://www.googleapis.com/auth/service.management.readonly", "https://www.googleapis.com/auth/servicecontrol", "https://www.googleapis.com/auth/trace.append"]
  }

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = false
    enable_vtpm                 = true
  }

  tags = ["http-server", "https-server", "lb-health-check", "ingress-http"]
  zone = "us-central1-c"
}

locals {
  instance_ip = google_compute_instance.genai-cluster-1.network_interface[0].access_config[0].nat_ip
}

resource "local_file" "genai_cluster_1_inventory" {
  content = templatefile("./cluster-inventory.tmpl", {
    instance_ip = local.instance_ip
  })
  filename = "../configuring/inventory/cluster.yml"
}
