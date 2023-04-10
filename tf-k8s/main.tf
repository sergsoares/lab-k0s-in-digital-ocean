terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = ">= 2.7.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 3.0"
    }
    k0s = {
      source  = "adnsio/k0s"
      version = "0.0.3"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.9.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.19.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

resource "digitalocean_droplet" "controller" {
  name     = "controller-${var.name}"
  image    = var.do_image
  region   = var.do_region
  size     = var.do_size
  ssh_keys = var.ssh_keys
}

resource "digitalocean_droplet" "workers" {
  count = var.do_worker_quantity

  name     = "worker${count.index}-${var.name}"
  image    = var.do_image
  region   = var.do_region
  size     = var.do_size
  ssh_keys = var.ssh_keys
}

data "http" "ip" {
  url = var.public_ip_dns
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

data "cloudflare_zone" "this" {
  name = var.domain
}

locals {
  controller_subdomain = "controller.${var.name}"
  controller_domain = "${local.controller_subdomain}.${var.domain}"
}

resource "cloudflare_record" "controllers" {
  zone_id = data.cloudflare_zone.this.id
  name    = local.controller_subdomain
  value   = digitalocean_droplet.controller.ipv4_address
  type    = "A"
  ttl     = 60
}

resource "cloudflare_record" "workers" {
  count =  var.do_worker_quantity

  zone_id = data.cloudflare_zone.this.id
  name    = "worker${count.index}.${var.name}"
  value   = digitalocean_droplet.workers[count.index].ipv4_address
  type    = "A"
  ttl     = 60
}

resource "cloudflare_record" "wildcard" {
  count =  var.do_worker_quantity

  zone_id = data.cloudflare_zone.this.id
  name    = "*.${var.name}"
  value   = digitalocean_droplet.workers[count.index].ipv4_address
  type    = "A"
  ttl     = 60
}

resource "k0s_cluster" "this" {
  name    = var.name
  version = var.k0s_kubernetes_version

  #https://github.com/k0sproject/k0sctl#host-fields
  
  hosts = [
    {
      role = "controller"

      ssh = {
        address  = "${local.controller_domain}"
        port     = var.k0s_port
        user     = var.k0s_host_user
        key_path = var.k0s_keypath
      }
    },
    {
      role = "worker"

      ssh = {
        address  = "worker0.${var.name}.${var.domain}"
        port     = var.k0s_port
        user     = var.k0s_host_user
        key_path = var.k0s_keypath
      }
    }
  ]

  # https://github.com/k0sproject/k0sctl#configuration-file
  config = <<YAML
apiVersion: k0s.k0sproject.io/v1beta1
kind: ClusterConfig
metadata:
  name: ${var.name}
spec:
  api:
    externalAddress: "${local.controller_domain}"
    sans:
      - "${local.controller_domain}"
      - ${digitalocean_droplet.controller.ipv4_address}
YAML
}



resource "time_sleep" "wait" {
  depends_on = [k0s_cluster.this]

  create_duration = "30s"
}

resource "local_sensitive_file" "kubeconfig" {
  depends_on = [time_sleep.wait]

  content  = k0s_cluster.this.kubeconfig
  filename = local.kubeconfig_path
}

locals {
  kubeconfig_path = pathexpand("${k0s_kubeconfig_local_base_path}/${var.name}")
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

  name             = "argocd"
  namespace        = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argocd"
  version          = "5.24.0"
  create_namespace = true
  wait             = true
  timeout          = 240

  # https://github.com/argoproj/argo-helm/issues/1780#issuecomment-1433743590
  set {
    # Run server without TLS
    name  = "configs.params.server\\.insecure"
    value = true
  }
}

resource "time_sleep" "wait_argocd" {
  depends_on = [helm_release.argocd]

  create_duration = "1m"
}

resource "kubectl_manifest" "argoapp" {
  depends_on = [time_sleep.wait_argocd]

  override_namespace = "argocd"
  yaml_body          = <<YAML
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