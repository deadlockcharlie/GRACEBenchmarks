terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Provider configuration - will use GOOGLE_APPLICATION_CREDENTIALS or gcloud auth
provider "google" {
  project = var.project_id
  region  = "us-east1"
}

# VPC Network (Global in GCP)
module "vpc" {
  source = "./modules/vpc"
  
  project_id   = var.project_id
  network_name = var.network_name
}

# Firewall Rules
module "firewall" {
  source = "./modules/firewall"
  
  project_id   = var.project_id
  network_name = module.vpc.network_name
  allowed_ssh_ips = var.allowed_ssh_ips
}

# Compute Instances - US East 1
module "compute_us_east1" {
  source = "./modules/compute"
  
  project_id      = var.project_id
  region          = "us-east1"
  zone            = "us-east1-b"
  instance_name   = "grace-us-east1"
  machine_type    = var.machine_type
  disk_size       = var.disk_size
  network_name    = module.vpc.network_name
  subnet_name     = module.vpc.subnet_us_east1_name
  ssh_key         = var.ssh_public_key
}

# Compute Instances - US West 1
module "compute_us_west1" {
  source = "./modules/compute"
  
  project_id      = var.project_id
  region          = "us-west1"
  zone            = "us-west1-a"
  instance_name   = "grace-us-west1"
  machine_type    = var.machine_type
  disk_size       = var.disk_size
  network_name    = module.vpc.network_name
  subnet_name     = module.vpc.subnet_us_west1_name
  ssh_key         = var.ssh_public_key
}

# Compute Instances - Europe West 1
module "compute_europe_west1" {
  source = "./modules/compute"
  
  project_id      = var.project_id
  region          = "europe-west1"
  zone            = "europe-west1-b"
  instance_name   = "grace-europe-west1"
  machine_type    = var.machine_type
  disk_size       = var.disk_size
  network_name    = module.vpc.network_name
  subnet_name     = module.vpc.subnet_europe_west1_name
  ssh_key         = var.ssh_public_key
}
