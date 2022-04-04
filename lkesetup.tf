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

resource "kubernetes_namespace" "deployment_ns" {
  metadata {
    name = "workspace"
  }
}

/* Manifest have to all be seperate, cannot have multiple in one file. 
   Because if yamldecode is only loading into one variable and not a map of
   vvariables.*/
resource "kubernetes_manifest" "single_manifest" {
  manifest = yamldecode(templatefile("${path.module}/single_manifest.yaml", {
    name  = "${local.session_name}",
    image = "nginx"
  }))
}
