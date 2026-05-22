output "ingress_public_ip" {
  value       = data.kubernetes_service.ingress_lb.status.load_balancer.ingress.ip
  description = "The external public static load-balancer IP address. Point your public DNS A-Record target string directly to this address."
}

output "application_secured_url" {
  value       = "https://${var.domain_name}"
  description = "The ultimate target secure browser directory to inspect your validated Nginx application."
}

output "gcr_pushed_image" {
  value       = docker_registry_image.gcr_push.name
  description = "The immutable Google Container Registry path string exported for auditing records."
}

output "application_secured_url" {
  value       = "https://${var.domain_name}"
  description = "The entrypoint to access your secure Nginx application behind Cloudflare."
}

output "cloudflare_record_status" {
  value       = cloudflare_record.nginx_dns.hostname
  description = "The active hostname managed by your Cloudflare automation script."
}





