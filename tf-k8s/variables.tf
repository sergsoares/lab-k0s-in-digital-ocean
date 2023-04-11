variable "name" {
  type = string
}

variable "ssh_keys" {
  type = list(any)
}

variable "domain" {
  type = string
}

variable "k0s_kubeconfig_local_base_path" {
  type    = string
  default = "~/.kube"
}

variable "public_ip_dns" {
  type    = string
  default = "https://ifconfig.me/ip"
}

variable "cloudflare_api_token" {
  sensitive = true
  type      = string
}

variable "do_config" {
  type    = string
  default = ""
}

variable "do_token" {
  sensitive = true
  type      = string
}

variable "do_image" {
  type    = string
  default = "ubuntu-22-04-x64"
}

variable "do_region" {
  type    = string
  default = "nyc3"
}

variable "do_size" {
  type    = string
  default = "s-1vcpu-1gb"
}

variable "do_worker_quantity" {
  type    = number
  default = 1
}

variable "k0s_port" {
  type    = number
  default = 22
}

variable "k0s_host_user" {
  type    = string
  default = "root"
}

variable "k0s_keypath" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
}

variable "k0s_kubernetes_version" {
  type    = string
  default = "1.23.8+k0s.0"
}