variable "ssh_key_pub" {}
variable "token" {}
variable "region" {}

provider "linode" {
  token = var.token
}

locals {
  session_name     = "lintoast-remote"
  hostname         = "lintoast"
  goversion        = "go1.18"
  nvmversion       = "v0.39.1"
  nvim_version     = "v0.6.1"
  stackscript_data = sensitive(templatefile("${path.module}/stackscriptsetup.sh.tftpl", { session_name = local.session_name, hostname = local.hostname, go_version = local.goversion, nvm_version = local.nvmversion, nvim_version = local.nvim_version }))
}

resource "random_password" "random_pass" {
  length  = 35
  special = true
  upper   = true
}

resource "linode_stackscript" "workspace-terraform" {
  label       = "workspace-terraform-${local.session_name}"
  description = "workspace deployed via terraform"
  script      = local.stackscript_data
  images      = ["linode/ubuntu20.04"]
  rev_note    = "initial terraform version"
}

resource "linode_instance" "workspace" {
  image           = "linode/ubuntu20.04"
  label           = local.session_name
  region          = var.region
  type            = "g6-standard-4"
  authorized_keys = [var.ssh_key_pub]
  root_pass       = random_password.random_pass.result
  stackscript_id  = linode_stackscript.workspace-terraform.id
  stackscript_data = {
    "hostname"     = local.hostname
    "go_version"   = local.goversion
    "nvm_version"  = local.nvmversion
    "session_name" = local.session_name
    "nvim_version" = local.nvim_version
  }
  private_ip = true
}

resource "linode_nodebalancer" "workspace-lb" {
  label                = "${local.session_name}-lb"
  region               = var.region
  client_conn_throttle = 2
  tags                 = [local.session_name]
}

resource "linode_nodebalancer_config" "workspace-lb-ssh" {
  nodebalancer_id = linode_nodebalancer.workspace-lb.id
  port            = 22
  protocol        = "tcp"
}

resource "linode_nodebalancer_node" "workspace-lb-node" {
  nodebalancer_id = linode_nodebalancer.workspace-lb.id
  config_id       = linode_nodebalancer_config.workspace-lb-ssh.id
  address         = "${linode_instance.workspace.private_ip_address}:22"
  label           = local.session_name
  weight          = 100
}
