# Tokens for the k3s cluster. The server token is the control plane's
# joining token; the (separate) agent token is what workers get installed
# with. The agent token cannot be used to join control planes, which keeps
# its exposure in worker cloud-init harmless.
resource "random_password" "k3s_server_token" {
  length  = 40
  special = false
}

resource "random_password" "k3s_agent_token" {
  length  = 40
  special = false
}

locals {
  private_ip = local.k3s_nodes["k3s-cp-node"].private_ip
}

locals {
  bootstrap_tpl_vars = {
    private_ip   = local.private_ip
    public_ip    = hcloud_server.control_plane.ipv4_address
    hostname     = hcloud_server.control_plane.name
    version      = var.k3s_version
    api_domain   = var.k3s_api_domain
    server_token = random_password.k3s_server_token.result
    agent_token  = random_password.k3s_agent_token.result
  }
}

output "control_plane_bootstrap" {
  value       = templatefile("${path.module}/templates/control_plane_bootstrap.sh.tftpl", local.bootstrap_tpl_vars)
  sensitive   = true
  description = "One-off k3s control plane install script. Run over SSH."
}

locals {
  worker_tpl_vars = {
    private_ip     = local.k3s_nodes["k3s-worker-1"].private_ip
    api_private_ip = local.k3s_nodes["k3s-cp-node"].private_ip
    hostname       = hcloud_server.worker["k3s-worker-1"].name
    version        = var.k3s_version
    agent_token    = random_password.k3s_agent_token.result
  }
}

output "worker_bootstrap" {
  value       = templatefile("${path.module}/templates/agent_bootstrap.sh.tftpl", local.worker_tpl_vars)
  sensitive   = true
  description = "One-off k3s agent install script for workers. Run over SSH."
}

output "k3s_agent_token" {
  value       = random_password.k3s_agent_token.result
  sensitive   = true
  description = "Agent token for adding worker nodes."
}

output "k3s_server_url" {
  value       = "https://${local.private_ip}:6443"
  description = "Join endpoint for workers (private network)."
}
