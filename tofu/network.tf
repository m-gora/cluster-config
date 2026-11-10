# Private network for k3s node-to-node traffic. Hetzner Cloud Firewalls do
# not filter private-network traffic, so no flannel/kubelet rules live here.
resource "hcloud_network" "k3s" {
  name     = "k3s-net"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "k3s" {
  network_id   = hcloud_network.k3s.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

locals {
  k3s_nodes = {
    "k3s-cp-node" = {
      private_ip = "10.0.1.10"
    }
  }
}
