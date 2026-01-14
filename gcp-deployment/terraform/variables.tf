variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "network_name" {
  description = "Name of the VPC network"
  type        = string
  default     = "grace-network"
}

variable "machine_type" {
  description = "GCE machine type (e2-micro for free tier, n2-standard-8 for production)"
  type        = string
  default     = "e2-micro"
}

variable "disk_size" {
  description = "Boot disk size in GB"
  type        = number
  default     = 30
}

variable "ssh_public_key" {
  description = "SSH public key for instance access (username:ssh-rsa AAAA... format)"
  type        = string
}

variable "allowed_ssh_ips" {
  description = "List of CIDR blocks allowed to SSH to instances"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
