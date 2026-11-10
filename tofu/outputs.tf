output "control_plane_public_ipv4" {
  value       = hcloud_server.control_plane.ipv4_address
  description = "Public IPv4 of the k3s control plane (API server)."
}

output "control_plane_private_ip" {
  # Mirrors local.k3s_nodes; the address stays stable, so no resource lookup.
  value       = local.k3s_nodes["k3s-cp-node"].private_ip
  description = "Private IP of the k3s control plane in the Hetzner network."
}

output "legacy_servers" {
  value = {
    for name, s in hcloud_server.legacy : name => {
      public_ipv4 = s.ipv4_address
      location    = s.location
    }
  }
  description = "Pre-k3s production servers that will move into the cluster."
}
