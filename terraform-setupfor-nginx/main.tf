 ==============================================================================
# 1. DOCKER IMAGE BUILD AND REGISTRY PUSHES
# ==============================================================================
resource "docker_image" "local_nginx" {
  name = "local-nginx:latest"
  build {
    context    = "." 
    dockerfile = "Dockerfile"
  }
}

resource "docker_registry_image" "docker_hub_push" {
  name = "${var.docker_hub_username}/my-nginx-app:latest"
  build {
    context    = "."
    dockerfile = "Dockerfile"
  }
  keep_remotely = true
}

resource "docker_registry_image" "gcr_push" {
  name = "gcr.io/${var.gcp_project_id}/my-nginx-app:latest"
  build {
    context    = "."
    dockerfile = "Dockerfile"
  }
  keep_remotely = true
}

# ==============================================================================
# 2. HELM INSTALLATIONS (INGRESS CONTROLLER & CERT-MANAGER)
# ==============================================================================
resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://github.io"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }
}

# ==============================================================================
# 3. KUBERNETES SECRET & DNS-01 CLUSTERISSUER
# ==============================================================================

# Stores your token securely within cert-manager namespace for the challenge to fetch
resource "kubernetes_secret" "cloudflare_api_token_secret" {
  depends_on = [helm_release.cert_manager]
  metadata {
    name      = "cloudflare-api-token-secret"
    namespace = "cert-manager"
  }

  type = "Opaque"

  data = {
    "api-token" = var.cloudflare_api_token
  }
}

# Reconfigured for DNS-01 verification
resource "kubernetes_manifest" "letsencrypt_issuer" {
  depends_on = [kubernetes_secret.cloudflare_api_token_secret]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.ssl_email
        privateKeySecretRef = {
          name = "letsencrypt-prod-account-key"
        }
        solvers = [
          {
            dns01 = {
              cloudflare = {
                apiTokenSecretRef = {
                  name = "cloudflare-api-token-secret"
                  key  = "api-token"
                }
              }
            }
          }
        ]
      }
    }
  }
}

# ==============================================================================
# 4. CLOUDFLARE DNS RECORD (PROXY ACTIVATED)
# ==============================================================================
resource "cloudflare_record" "nginx_dns" {
  zone_id = var.cloudflare_zone_id
  name    = split(".", var.domain_name)[0] # Extracts "nginx" subdomain from full host configuration
  value   = data.kubernetes_service.ingress_lb.status.load_balancer.ingress.ip
  type    = "A"
  proxied = true # Securely route your browser calls directly via Cloudflare's CDN network proxy
}

# ==============================================================================
# 5. KUBERNETES APPLICATION MANIFESTS
# ==============================================================================
resource "kubernetes_deployment" "nginx_deployment" {
  metadata {
    name = "nginx-deployment"
    labels = {
      app = "nginx-app"
    }
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "nginx-app"
      }
    }
    template {
      metadata {
        labels = {
          app = "nginx-app"
        }
      }
      spec {
        container {
          name  = "nginx-container"
          image = docker_registry_image.gcr_push.name
          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "nginx_service" {
  metadata {
    name = "nginx-service"
  }
  spec {
    selector = {
      app = "nginx-app"
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "nginx_ingress_route" {
  depends_on = [kubernetes_manifest.letsencrypt_issuer]

  metadata {
    name = "nginx-ingress"
    annotations = {
      "kubernetes.io/ingress.class"              = "nginx"
      "cert-manager.io/cluster-issuer"           = "letsencrypt-prod"
      "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
    }
  }

  spec {
    tls {
      hosts       = [var.domain_name]
      secret_name = "nginx-app-tls-cert"
    }
    rule {
      host = var.domain_name
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.nginx_service.metadata.name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
