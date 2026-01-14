variable "project_id" {
  type = string
}

variable "network_name" {
  type = string
}

variable "allowed_ssh_ips" {
  type = list(string)
}

# Allow SSH from specified IPs
resource "google_compute_firewall" "ssh" {
  name    = "${var.network_name}-allow-ssh"
  network = var.network_name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.allowed_ssh_ips
  target_tags   = ["grace-benchmark"]
}

# Allow internal communication between instances
resource "google_compute_firewall" "internal" {
  name    = "${var.network_name}-allow-internal"
  network = var.network_name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_tags = ["grace-benchmark"]
  target_tags = ["grace-benchmark"]
}

# Allow application ports from anywhere (for benchmarking)
resource "google_compute_firewall" "app" {
  name    = "${var.network_name}-allow-app"
  network = var.network_name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["3000", "7000", "7001", "7474", "7687", "8529", "27017", "9042"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["grace-benchmark"]
}
