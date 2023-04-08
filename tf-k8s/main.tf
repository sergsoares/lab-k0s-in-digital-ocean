terraform {
  required_providers {
    # VPS
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = ">= 2.7.0"
    }
    
    # DNS
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 3.0"
    }
    
    # K8S Distribution
    k0s = {
      source = "adnsio/k0s"
      version = "0.0.3"
    }
    
    # K8S manifest management (Kubectl & Helm)
    kubectl = {
      source = "gavinbunney/kubectl"
      version = "1.14.0"
    }
    helm = {
      source = "hashicorp/helm"
      version = "2.9.0"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.19.0"
    }
    tls = {
      source = "hashicorp/tls"
      version = "4.0.4"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

resource "digitalocean_droplet" "vps" {
  name   = var.name
  image  = var.do_image
  region = var.do_region
  size   = var.do_size
  ssh_keys = var.ssh_keys
}

data "http" "ip" {
  url = "https://ifconfig.me/ip"
}

resource "digitalocean_firewall" "vps" {
  name = "public-and-internal-ssh-and-k8s"

  droplet_ids = [digitalocean_droplet.vps.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["${data.http.ip.response_body}/32"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "6443"
    source_addresses = ["${data.http.ip.response_body}/32"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "icmp"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "53"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "53"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "443"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

data "cloudflare_zone" "this" {
  name = var.domain
}

resource "cloudflare_record" "this" {
  zone_id = data.cloudflare_zone.this.id
  name    = var.name
  value   = digitalocean_droplet.vps.ipv4_address
  type    = "A"
  ttl     = 60
}

resource "cloudflare_record" "wildcard" {
  zone_id = data.cloudflare_zone.this.id
  name    = "*.${var.name}"
  value   = digitalocean_droplet.vps.ipv4_address
  type    = "A"
  ttl     = 60
}

resource "k0s_cluster" "this" {
  name    = var.name
  version = var.k8s_version
  
  #https://github.com/k0sproject/k0sctl#host-fields
  hosts = [
    {
      role = "single"

      ssh = {
        address  = digitalocean_droplet.vps.ipv4_address
        port     = var.k0s_port
        user     = var.k0s_host_user
        key_path = var.k0s_keypath
      }
    }
  ] 
  config = var.config
}

locals {
  kubeconfig_path = pathexpand("~/.kube/${var.name}")
}
resource "time_sleep" "wait_30_seconds" {
  depends_on = [k0s_cluster.this]

  create_duration = "50s"
}

resource "local_sensitive_file" "kubeconfig" {
  depends_on = [time_sleep.wait_30_seconds]
  
  content  = k0s_cluster.this.kubeconfig
  filename = local.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = local.kubeconfig_path
  }
}

provider "kubectl" {
  config_path = local.kubeconfig_path
}

provider "kubernetes" {
  config_path = local.kubeconfig_path
}

resource "helm_release" "argocd" {
  depends_on = [
    local_sensitive_file.kubeconfig
  ]

  name       = "argo-cd"
  namespace  = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "5.24.0"
  create_namespace = true
  wait = true
  timeout = 240

  # https://github.com/argoproj/argo-helm/issues/1780#issuecomment-1433743590
  set {
    # Run server without TLS
    name  = "configs.params.server\\.insecure"
    value = true
  }
}

resource "kubectl_manifest" "argoapp" {
  override_namespace = "argo-cd"
  yaml_body = <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: addons
  namespace: argo-cd
spec:
  project: default
  source:
    repoURL: https://github.com/sergsoares/lab-k0s-in-digital-ocean.git
    targetRevision: HEAD
    path: addons
  destination:
    server: https://kubernetes.default.svc
    namespace: argo-cd
  syncPolicy:
    automated: {}
    syncOptions:
      - CreateNamespace=true
YAML
}