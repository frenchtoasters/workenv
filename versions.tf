terraform {
  cloud {
    organization = "cloudwork"
    workspaces {
      name = "Linode_Prod"
    }
  }
  required_providers {
    linode = {
      source  = "linode/linode"
      version = ">=1.26.1"
    }
  }
}
