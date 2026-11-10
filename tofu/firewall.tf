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
  server_ids  = [for s in hcloud_server.legacy : s.id]
}

import {
  to = hcloud_firewall.main
  id = "10256505"
}

import {
  to = hcloud_firewall_attachment.main
  id = "10256505"
}
