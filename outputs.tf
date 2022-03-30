output "node_addres" {
  value = linode_instance.workspace.ipv4
}

output "lb_address" {
  value = linode_nodebalancer.workspace-lb.ipv4
}

output "private_key" {
  value     = tls_private_key.lintoast-key.private_key_pem
  sensitive = true
}
