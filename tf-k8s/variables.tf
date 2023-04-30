variable "name" {
  type = string
}

variable "domain" {
  type = string
}

variable "cloudflare_ttl" {
  type    = number
  default = 60
}

variable "prevent_destroy_controller" {
  type    = bool
  default = false
}

variable "ssh_key_local_base_path" {
  type    = string
  default = "~/.ssh"
}

variable "k0s_kubeconfig_local_base_path" {
  type    = string
  default = "~/.kube"
}

variable "public_ip_dns" {
  type    = string
  default = "https://ifconfig.me/ip"
}

variable "CLOUDFLARE_API_TOKEN" {
  sensitive = true
  type      = string
}

variable "DIGITAL_OCEAN_TOKEN" {
  sensitive = true
  type      = string
}

variable "do_config" {
  type    = string
  default = ""
}

variable "do_image" {
  type    = string
  default = "ubuntu-22-04-x64"
}

variable "do_region" {
  type    = string
  default = "nyc3"
}

# Digital Ocean Slug documentation - https://slugs.do-api.dev/
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

variable "argo_version" {
  type    = string
  default = "5.24.0"
}

variable "argo_timeout" {
  type    = number
  default = 240
}

