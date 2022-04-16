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
  depends_on = [
    linode_lke_cluster.workspace-cluster
  ]
}

resource "kubernetes_namespace" "deployment_ns" {
  metadata {
    name = "workspace"
  }
  depends_on = [
    linode_lke_cluster.workspace-cluster
  ]
}

/* Manifest have to all be seperate, cannot have multiple in one file. 
   Because if `yamldecode` is only loading into one variable and not a map of
   variables. https://www.terraform.io/language/functions/yamldecode note it 
   can only do one.*/
resource "kubernetes_manifest" "single_manifest" {
  manifest = yamldecode(templatefile("${path.module}/single_manifest.yaml", {
    name  = "${local.session_name}",
    image = "nginx"
  }))
  depends_on = [
    kubernetes_namespace.workspace
  ]
}

provider "helm" {
  kubernetes {
    host                   = local.kubeconfig.clusters[0].cluster.server
    token                  = local.kubeconfig.users[0].user.token
    cluster_ca_certificate = base64decode(local.kubeconfig.clusters[0].cluster.certificate-authority-data)
  }
}

provider "kubectl" {
  host                   = local.kubeconfig.clusters[0].cluster.server
  token                  = local.kubeconfig.users[0].user.token
  cluster_ca_certificate = base64decode(local.kubeconfig.clusters[0].cluster.certificate-authority-data)
}

data "kubectl_file_documents" "multi_doc" {
  content = templatefile("${path.module}/multi_manifest.yaml", {
    name  = "${local.session_name}",
    image = "nginx"
  })
  depends_on = [
    kubernetes_namespace.workspace
  ]
}

resource "kubectl_manifest" "multi_manifests" {
  for_each  = data.kubectl_file_documents.multi_doc.manifests
  yaml_body = each.value
  depends_on = [
    kubernetes_namespace.workspace
  ]
}

module "template_files" {
  source = "hashicorp/dir/template"

  base_dir = "${path.module}/templatedir/"
  template_vars = {
    name  = "${local.session_name}",
    image = "nginx"
  }
}

data "kubectl_file_documents" "multi_dir" {
  for_each = module.template_files.files
  content  = yamldecode(each.value.content)
  depends_on = [
    kubernetes_namespace.workspace
  ]
}


