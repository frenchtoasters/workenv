output "node_addres" {
  value = linode_instance.workspace.ipv4
}

output "lb_address" {
  value = linode_nodebalancer.workspace-lb.ipv4
}
