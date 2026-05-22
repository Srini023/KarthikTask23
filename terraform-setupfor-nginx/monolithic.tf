# ==============================================================================
# 1. PROVIDERS, CONFIGURATIONS & VARIABLES
# ==============================================================================
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

variable "docker_hub_username" {
  type        = string
  default     = "2823"
  description = "Your Docker Hub username"
}

variable "docker_hub_password" {
  type        = string
  sensitive   = true
  description = "Your Docker Hub password or personal access token"
}

variable "domain_name" {
  type        = string
  default     = "://yourdomain.com" # !!! REPLACE WITH YOUR ACTUAL DOMAIN !!!
  description = "The registered domain or subdomain used to access your application"
}

variable "ssl_email" {
  type        = string
  default     = "your-email@example.com" # !!! REPLACE WITH YOUR ACTUAL EMAIL !!!
  description = "Email address for Let's Encrypt urgent renewal notices"
}

provider "google" {
  project = "srinisre023"
  region  = "us-central1"
}

data "google_client_config" "default" {}

provider "docker" {
  registry_auth {
    address  = "gcr.io"
    username = "oauth2access"
    password = data.google_client_config.default.access_token
  }

  registry_auth {
    address  = "registry-1.docker.io"
    username = var.docker_hub_username
    password = var.docker_hub_password
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config" 
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

# ==============================================================================
# 2. DOCKER IMAGE BUILD AND REGISTRY PUSHES
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
  name = "gcr.io/srinisre023/my-nginx-app:latest"
  build {
    context    = "."
    dockerfile = "Dockerfile"
  }
  keep_remotely = true
}

# ==============================================================================
# 3. HELM INSTALLATIONS (INGRESS CONTROLLER & CERT-MANAGER)
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
  repository       = "https://jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }
}

# ==============================================================================
# 4. CERT-MANAGER ISSUER CONFIGURATION
# ==============================================================================

resource "kubernetes_manifest" "letsencrypt_issuer" {
  depends_on = [helm_release_cert_manager]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = "https://letsencrypt.org"
        email  = var.ssl_email
        privateKeySecretRef = {
          name = "letsencrypt-prod-account-key"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                class = "nginx"
              }
            }
          }
        ]
      }
    }
  }
}

# ==============================================================================
# 5. KUBERNETES APPLICATION MANIFESTS (DEPLOYMENT, SERVICE, INGRESS)
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
    type = "ClusterIP" # External access is managed via the Ingress rule below
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

# ==============================================================================
# 6. APPLICATION OUTPUTS
# ==============================================================================

data "kubernetes_service" "ingress_lb" {
  depends_on = [helm_release_nginx_ingress]
  metadata {
    name      = "ingress-nginx-controller"
    namespace = "ingress-nginx"
  }
}

output "ingress_public_ip" {
  value       = data.kubernetes_service.ingress_lb.status.load_balancer.ingress.ip
  description = "Map your domain DNS record (A record) to this specific public IP address."
}
