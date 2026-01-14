variable "project_id" {
  type = string
}

variable "network_name" {
  type = string
}

# VPC Network (Global)
resource "google_compute_network" "grace_network" {
  name                    = var.network_name
  auto_create_subnetworks = false
  project                 = var.project_id
}

# Subnet - US East 1
resource "google_compute_subnetwork" "us_east1" {
  name          = "${var.network_name}-us-east1"
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-east1"
  network       = google_compute_network.grace_network.id
  project       = var.project_id
}

# Subnet - US West 1
resource "google_compute_subnetwork" "us_west1" {
  name          = "${var.network_name}-us-west1"
  ip_cidr_range = "10.1.1.0/24"
  region        = "us-west1"
  network       = google_compute_network.grace_network.id
  project       = var.project_id
}

# Subnet - Europe West 1
resource "google_compute_subnetwork" "europe_west1" {
  name          = "${var.network_name}-europe-west1"
  ip_cidr_range = "10.2.1.0/24"
  region        = "europe-west1"
  network       = google_compute_network.grace_network.id
  project       = var.project_id
}

output "network_name" {
  value = google_compute_network.grace_network.name
}

output "network_self_link" {
  value = google_compute_network.grace_network.self_link
}

output "subnet_us_east1_name" {
  value = google_compute_subnetwork.us_east1.name
}

output "subnet_us_west1_name" {
  value = google_compute_subnetwork.us_west1.name
}

output "subnet_europe_west1_name" {
  value = google_compute_subnetwork.europe_west1.name
}
