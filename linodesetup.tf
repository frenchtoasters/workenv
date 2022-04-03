variable "ssh_key_pub" {}
variable "token" {}
variable "gh_token" {}
variable "region" {}
variable "ssh_priv_key" {}

provider "linode" {
  token = var.token
}

provider "github" {
  token = var.gh_token
}

locals {
  session_name = "lintoast-remote"
  hostname     = "lintoast"
  goversion    = "go1.18"
  nvmversion   = "v0.39.1"
  nvim_version = "v0.6.1"
  gh_version   = "2.6.0"
  stackscript_data = templatefile("${path.module}/stackscriptsetup.sh",
    {
      session_name = local.session_name,
      hostname     = local.hostname,
      go_version   = local.goversion,
      nvm_version  = local.nvmversion,
      nvim_version = local.nvim_version,
      gh_version   = local.gh_version
    }
  )
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
  label  = local.session_name
  region = var.region
  type   = "g6-standard-4"

  disk {
    label           = "ubuntu20.04"
    size            = 30000
    filesystem      = "ext4"
    image           = "linode/ubuntu20.04"
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
  }

  config {
    label  = "04config"
    kernel = "linode/latest-64bit"
    devices {
      sda {
        disk_label = "ubuntu20.04"
      }
      sdb {
        volume_id = linode_volume.home_dir.id
      }
    }
    root_device = "/dev/sda"
  }
  boot_config_label = "04config"

  private_ip = true
}

resource "linode_volume" "home_dir" {
  label  = "home_dir"
  size   = 100
  region = var.region
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

resource "tls_private_key" "lintoast-key" {
  algorithm = "RSA"
}

resource "github_user_ssh_key" "lintoast-ssh" {
  title = "${local.session_name}-ssh"
  key   = tls_private_key.lintoast-key.public_key_openssh
}

resource "null_resource" "add_ssh_priv" {
  triggers = {
    priv_key = tls_private_key.lintoast-key.private_key_pem
  }
  provisioner "file" {
    content     = tls_private_key.lintoast-key.private_key_pem
    destination = "/root/.ssh/id_rsa"
    connection {
      type        = "ssh"
      user        = "root"
      private_key = base64decode(var.ssh_priv_key)
      host        = linode_instance.workspace.ip_address
    }
  }
}

resource "null_resource" "add_ssh_pub" {
  triggers = {
    pub_key = tls_private_key.lintoast-key.public_key_pem
  }
  provisioner "file" {
    content     = tls_private_key.lintoast-key.public_key_pem
    destination = "/root/.ssh/id_rsa.pub"
    connection {
      type        = "ssh"
      user        = "root"
      private_key = base64decode(var.ssh_priv_key)
      host        = linode_instance.workspace.ip_address
    }
  }
}

