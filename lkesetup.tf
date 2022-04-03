locals {
  kubeconfig = yamldecode(base64decode(linode_lke_cluster.workspace-cluster.kubeconfig))
}

resource "linode_lke_cluster" "workspace-cluster" {
  label       = "${local.session_name}-cluster"
  k8s_version = "1.22"
  region      = "us-southeast"
  tags        = ["${local.session_name}-cluster"]

  pool {
    type  = "g6-standard-2"
    count = 1
  }
}

provider "kubernetes" {
  host                   = local.kubeconfig.clusters[0].cluster.server
  token                  = local.kubeconfig.users[0].user.token
  cluster_ca_certificate = base64decode(local.kubeconfig.clusters[0].cluster.certificate-authority-data)
}

resource "kubernetes_namespace" "workspace" {
  metadata {
    name = "${local.session_name}-ns"
  }
}

resource "kubernetes_manifest" "test_pod" {
  manifest = yamldecode(templatefile("${path.module}/manifest.yaml.tftpl", {
    name  = "${local.session_name}",
    image = "nginx"
  }))
}
