variable "docker_hub_username" {
  type        = string
  default     = "2823"
}

variable "docker_hub_password" {
  type        = string
  sensitive   = true
}

variable "gcp_project_id" {
  type        = string
  default     = "srinisre023"
}

variable "gcp_region" {
  type        = string
  default     = "us-central1"
}

variable "domain_name" {
  type        = string
  description = "The domain name (e.g., ://yourdomain.com)"
}

variable "ssl_email" {
  type        = string
  description = "Administrative email for Let's Encrypt certificates"
}

variable "kube_config_path" {
  type        = string
  default     = "~/.kube/config"
}

variable "cloudflare_api_token" {
  type        = string
  sensitive   = true
  description = "Cloudflare API token with Zone.DNS.Edit permissions"
}

variable "cloudflare_zone_id" {
  type        = string
  description = "The Zone ID for your domain found on Cloudflare's overview panel"
}
