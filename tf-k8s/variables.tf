variable "do_token" { 
  sensitive = true
  type = string 
}


variable "ssh_keys" { type = list(any) }
variable "name" { type = string }
variable "domain" { type = string }


variable "cloudflare_api_token" { 
  sensitive = true
  type = string 
}
variable "cloudflare_email" { type = string }

variable "config" { type = string }

variable "do_image" {
  type    = string
  default = "ubuntu-22-04-x64"
}

variable "k0s_host_user" {
  type    = string
  default = "root"
}

variable "k0s_keypath" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
}
variable "k0s_port" {
  type    = number
  default = 22
}

variable "do_region" {
  type    = string
  default = "nyc3"
}
variable "do_size" {
  type    = string
  default = "s-1vcpu-1gb"
}

variable "k8s_version" {
  type    = string
  default = "1.23.8+k0s.0"
}

