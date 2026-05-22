# Fetches active identity tokens from your local authenticated gcloud configuration profile
data "google_client_config" "default" {}

# Tracks runtime changes applied to the ingress system controller to extract live IP mappings
data "kubernetes_service" "ingress_lb" {
  depends_on = [helm_release_nginx_ingress]
  metadata {
    name      = "ingress-nginx-controller"
    namespace = "ingress-nginx"
  }
}
