resource "hcloud_firewall" "main" {
  name = "firewall-1"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = var.admin_cidrs
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "6443"
    source_ips = var.admin_cidrs
  }

  # SFTP sidecar for Foundry (foundry13-sftp Service, ServiceLB node
  # port). Deliberately not 22 — that port is node SSH. admin_cidrs like
  # the other admin services.
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "8222"
    source_ips = var.admin_cidrs
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_firewall_attachment" "main" {
  firewall_id = hcloud_firewall.main.id

  # Explicit for the imported legacy servers, plus a label selector so any
  # future k3s node (cluster=k3s label) is covered automatically.
  server_ids = [for s in hcloud_server.legacy : s.id]

  label_selectors = ["cluster=k3s"]
}

import {
  to = hcloud_firewall.main
  id = "10256505"
}

import {
  to = hcloud_firewall_attachment.main
  id = "10256505"
}
