terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.27.1"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "3.35.0"
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

locals {
  ssh_publickey_path = pathexpand("~/.ssh/${var.name}.pub")
  ssh_privatekey_path = pathexpand("~/.ssh/${var.name}")
}

resource "digitalocean_ssh_key" "base" {
  name       = "${var.name}-key"
  public_key = file(local.ssh_publickey_path)
}

provider "digitalocean" {
  token = var.DIGITAL_OCEAN_TOKEN
}

resource "digitalocean_droplet" "controller" {
  name     = "controller-${var.name}"
  image    = var.do_image
  region   = var.do_region
  size     = var.do_size
  ssh_keys = [digitalocean_ssh_key.base.fingerprint]
}

resource "digitalocean_droplet" "workers" {
  count = var.do_worker_quantity

  name     = "worker${count.index}-${var.name}"
  image    = var.do_image
  region   = var.do_region
  size     = var.do_size
  ssh_keys = [digitalocean_ssh_key.base.fingerprint]
}

data "http" "ip" {
  url = var.public_ip_dns
}

provider "cloudflare" {
  api_token = var.CLOUDFLARE_API_TOKEN
}

data "cloudflare_zone" "this" {
  name = var.domain
}

locals {
  controller_subdomain = "controller.${var.name}"
  controller_domain    = "${local.controller_subdomain}.${var.domain}"
}

resource "cloudflare_record" "controller" {
  zone_id = data.cloudflare_zone.this.id
  name    = local.controller_subdomain
  value   = digitalocean_droplet.controller.ipv4_address
  type    = "A"
  ttl     = var.cloudflare_ttl
}

resource "cloudflare_record" "workers" {
  count = var.do_worker_quantity

  zone_id = data.cloudflare_zone.this.id
  name    = "worker${count.index}.${var.name}"
  value   = digitalocean_droplet.workers[count.index].ipv4_address
  type    = "A"
  ttl     = var.cloudflare_ttl
}

resource "cloudflare_record" "wildcard" {
  count = var.do_worker_quantity

  zone_id = data.cloudflare_zone.this.id
  name    = "*.${var.name}"
  value   = digitalocean_droplet.workers[count.index].ipv4_address
  type    = "A"
  ttl     = var.cloudflare_ttl
}

locals {
  workerNodes = [for i, v in range(var.do_worker_quantity) :
    {
      role = "worker"

      ssh = {
        address  = digitalocean_droplet.workers[i].ipv4_address
        port     = var.k0s_port
        user     = var.k0s_host_user
        key_path = local.ssh_privatekey_path
      }
    }
  ]
}

resource "k0s_cluster" "this" {
  name    = var.name
  version = var.k0s_kubernetes_version

  #https://github.com/k0sproject/k0sctl#host-fields
  hosts = concat([
    {
      role = "controller+worker"

      ssh = {
        address  = digitalocean_droplet.controller.ipv4_address
        port     = var.k0s_port
        user     = var.k0s_host_user
        key_path = local.ssh_privatekey_path
      }
    }
  ], local.workerNodes)

  # https://github.com/k0sproject/k0sctl#configuration-file
  config = <<YAML
apiVersion: k0s.k0sproject.io/v1beta1
kind: ClusterConfig
metadata:
  name: ${var.name}
spec:
  api:
    externalAddress: ${digitalocean_droplet.controller.ipv4_address}
    sans:
      - ${digitalocean_droplet.controller.ipv4_address}
      - ${cloudflare_record.controller.hostname}
YAML
}

resource "local_sensitive_file" "kubeconfig" {
  content  = k0s_cluster.this.kubeconfig
  filename = local.kubeconfig_path
}

locals {
  kubeconfig_path = pathexpand("${var.k0s_kubeconfig_local_base_path}/${var.name}")
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

resource "helm_release" "traefik" {
  depends_on = [
    local_sensitive_file.kubeconfig
  ]

  name       = "traefik"
  namespace  = "traefik"
  repository = "https://helm.traefik.io/traefik"
  chart      = "traefik"
  create_namespace = true
  wait = true
  timeout = 240
  version = "22.1.0"

  values = [
    "${file("helm/traefik.yaml")}"
  ]
}