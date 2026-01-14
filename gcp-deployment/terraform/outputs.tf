output "instance_details" {
  description = "Details of all deployed instances"
  value = {
    us_east1 = {
      region      = "us-east1"
      zone        = module.compute_us_east1.zone
      public_ip   = module.compute_us_east1.public_ip
      private_ip  = module.compute_us_east1.private_ip
      instance_id = module.compute_us_east1.instance_id
    }
    us_west1 = {
      region      = "us-west1"
      zone        = module.compute_us_west1.zone
      public_ip   = module.compute_us_west1.public_ip
      private_ip  = module.compute_us_west1.private_ip
      instance_id = module.compute_us_west1.instance_id
    }
    europe_west1 = {
      region      = "europe-west1"
      zone        = module.compute_europe_west1.zone
      public_ip   = module.compute_europe_west1.public_ip
      private_ip  = module.compute_europe_west1.private_ip
      instance_id = module.compute_europe_west1.instance_id
    }
  }
}

output "ssh_commands" {
  description = "SSH commands for each instance"
  value = {
    us_east1      = "gcloud compute ssh grace-us-east1 --zone=us-east1-b"
    us_west1      = "gcloud compute ssh grace-us-west1 --zone=us-west1-a"
    europe_west1  = "gcloud compute ssh grace-europe-west1 --zone=europe-west1-b"
  }
}

output "distribution_config" {
  description = "Configuration for gcp-distribution-config.json"
  value = {
    replicas = [
      {
        id       = 1
        region   = "us-east1"
        host     = module.compute_us_east1.public_ip
        app_port = 3000
      },
      {
        id       = 2
        region   = "us-west1"
        host     = module.compute_us_west1.public_ip
        app_port = 3000
      },
      {
        id       = 3
        region   = "europe-west1"
        host     = module.compute_europe_west1.public_ip
        app_port = 3000
      }
    ]
  }
}
