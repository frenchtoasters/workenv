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

/* Use a helm chart */
provider "helm" {
  kubernetes {
    host                   = local.kubeconfig.clusters[0].cluster.server
    token                  = local.kubeconfig.users[0].user.token
    cluster_ca_certificate = base64decode(local.kubeconfig.clusters[0].cluster.certificate-authority-data)
  }
}

/* Work with kubectl */
provider "kubectl" {
  host                   = local.kubeconfig.clusters[0].cluster.server
  token                  = local.kubeconfig.users[0].user.token
  cluster_ca_certificate = base64decode(local.kubeconfig.clusters[0].cluster.certificate-authority-data)
  load_config_file       = false
}

/* Apply single yaml doc with multiple yaml resources defined */
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

/* Apply a directory of manifests templates, passing terraform resource 
   information */
data "kubectl_path_documents" "multi_dir" {
  pattern = "${path.module}/templatedir/*.yaml"
  vars = {
    name  = "${local.session_name}",
    image = "nginx"
  }
}

/* You can save the templated manifests to disk for analysis. */
resource "local_file" "file_dir_temp" {
  count    = length(data.kubectl_path_documents.multi_dir.documents)
  content  = element(data.kubectl_path_documents.multi_dir.documents, count.index)
  filename = "${path.module}/templatedir-temp/${count.index}.yaml"
}

/* Load a directory of templated manifests  */
data "kubectl_path_documents" "temp_multi_dir" {
  pattern = "${path.module}/templatedir-temp/*.yaml"
  depends_on = [
    local_file.file_dir_temp
  ]
}

/* Apply the loaded dirctory of manifests */
resource "kubectl_manifest" "dir_manifests" {
  count     = length(data.kubectl_path_documents.multi_dir.documents)
  yaml_body = element(data.kubectl_path_documents.temp_multi_dir.documents, count.index)
  depends_on = [
    kubernetes_namespace.workspace,
    data.kubectl_path_documents.temp_multi_dir
  ]
}

/* This will create all the documents in a directory, with the condition that
   it will not create multi-doc yaml files correctly. It will only create the
   first yaml doc in the file. Took way to long to figure out though so im 
   leaving it here.*/
/* data "kubectl_file_documents" "multi_dir" { */
/*   for_each = module.template_files.files */
/*   content  = each.value.content */
/*   depends_on = [ */
/*     kubernetes_namespace.workspace */
/*   ] */
/* } */

/* resource "kubectl_manifest" "dir_manifests" { */
/* This part especially */
/*   for_each = { */
/*     for doc in data.kubectl_file_documents.multi_dir : doc.id => doc */
/*   } */
/*   yaml_body = each.value.manifests */
/*   depends_on = [ */
/*     kubernetes_namespace.workspace */
/*   ] */
/* } */

