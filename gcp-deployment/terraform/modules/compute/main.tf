variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "instance_name" {
  type = string
}

variable "machine_type" {
  type = string
}

variable "disk_size" {
  type = number
}

variable "network_name" {
  type = string
}

variable "subnet_name" {
  type = string
}

variable "ssh_key" {
  type = string
}

# Compute Instance
resource "google_compute_instance" "grace_instance" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone
  project      = var.project_id

  tags = ["grace-benchmark"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = var.disk_size
      type  = "pd-standard"
    }
  }

  network_interface {
    network    = var.network_name
    subnetwork = var.subnet_name

    access_config {
      // Ephemeral public IP
    }
  }

  metadata = {
    ssh-keys = var.ssh_key
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    set -e
    
    # Function to wait for dpkg lock to be released
    wait_for_dpkg_lock() {
        echo "Waiting for dpkg lock to be released..."
        while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
            sleep 5
        done
        echo "dpkg lock released"
    }
    
    # Wait for any existing dpkg processes to complete
    wait_for_dpkg_lock
    
    # Update system
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common jq
    
    # Install Docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    
    # Wait for lock again after adding repository
    wait_for_dpkg_lock
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Start and enable Docker service
    systemctl start docker
    systemctl enable docker
    
    # Add default user to docker group and create docker startup script
    DEFAULT_USER=$(ls /home | head -1)
    if [ ! -z "$DEFAULT_USER" ]; then
        usermod -aG docker "$DEFAULT_USER"
        
        # Create a script to fix Docker permissions on login
        cat > /home/$DEFAULT_USER/start-docker.sh << 'DOCKER_SCRIPT'
#!/bin/bash
# Fix Docker permissions and start Docker if needed
sudo systemctl start docker 2>/dev/null || true
sudo chmod 666 /var/run/docker.sock 2>/dev/null || true
echo "Docker is ready! You can now run: docker ps"
DOCKER_SCRIPT
        chmod +x /home/$DEFAULT_USER/start-docker.sh
        chown $DEFAULT_USER:$DEFAULT_USER /home/$DEFAULT_USER/start-docker.sh
        
        # Add to bashrc for automatic setup
        echo "" >> /home/$DEFAULT_USER/.bashrc
        echo "# GRACE Docker setup" >> /home/$DEFAULT_USER/.bashrc
        echo "if [ -f ~/start-docker.sh ] && [ ! -w /var/run/docker.sock ]; then" >> /home/$DEFAULT_USER/.bashrc
        echo "    echo 'Setting up Docker permissions...'" >> /home/$DEFAULT_USER/.bashrc
        echo "    ~/start-docker.sh" >> /home/$DEFAULT_USER/.bashrc
        echo "fi" >> /home/$DEFAULT_USER/.bashrc
    fi
    
    # Set proper permissions on Docker socket
    chmod 666 /var/run/docker.sock
    
    # Install Python3 and pip
    wait_for_dpkg_lock
    apt-get install -y python3 python3-pip python3-venv
    
    # Install Java 11 (for YCSB)
    apt-get install -y openjdk-11-jdk

    # Install Maven
    apt-get install -y maven
    
    # Create signal file
    touch /tmp/user-data-complete
    
    echo "GRACE GCP instance initialization complete!"
  EOF

  labels = {
    project = "grace-benchmark"
    region  = var.region
  }

  allow_stopping_for_update = true
}

output "instance_id" {
  value = google_compute_instance.grace_instance.instance_id
}

output "public_ip" {
  value = google_compute_instance.grace_instance.network_interface[0].access_config[0].nat_ip
}

output "private_ip" {
  value = google_compute_instance.grace_instance.network_interface[0].network_ip
}

output "zone" {
  value = var.zone
}
