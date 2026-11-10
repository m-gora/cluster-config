# Production servers that predate this repo. They run mission-critical
# applications that are going to be moved into the k3s cluster, so they must
# never be replaced or destroyed by OpenTofu.
locals {
  legacy_servers = {
    "ubuntu-4gb-nbg1-1" = {
      id          = 114308431
      server_type = "cx23"
      image       = "ubuntu-24.04"
      location    = "nbg1"
      ipv4_id     = 108969418
      ipv6_id     = 108969419
    }
    "ubuntu-4gb-fsn1-1" = {
      id          = 167475168
      server_type = "cx23"
      image       = "ubuntu-26.04"
      location    = "fsn1"
      ipv4_id     = 151687654
      ipv6_id     = 151687655
    }
  }
}

resource "hcloud_primary_ip" "legacy_ipv4" {
  for_each = local.legacy_servers

  name        = "primary_ip-${each.value.ipv4_id}"
  type        = "ipv4"
  location    = each.value.location
  auto_delete = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "hcloud_primary_ip" "legacy_ipv6" {
  for_each = local.legacy_servers

  name        = "primary_ip-${each.value.ipv6_id}"
  type        = "ipv6"
  location    = each.value.location
  auto_delete = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "hcloud_server" "legacy" {
  for_each = local.legacy_servers

  name        = each.key
  server_type = each.value.server_type
  image       = each.value.image
  location    = each.value.location
  ssh_keys    = [hcloud_ssh_key.marco.id]

  public_net {
    ipv4_enabled = true
    ipv4         = hcloud_primary_ip.legacy_ipv4[each.key].id
    ipv6_enabled = true
    ipv6         = hcloud_primary_ip.legacy_ipv6[each.key].id
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [ssh_keys, image, user_data]
  }
}

import {
  for_each = local.legacy_servers
  to       = hcloud_server.legacy[each.key]
  id       = each.value.id
}

import {
  for_each = local.legacy_servers
  to       = hcloud_primary_ip.legacy_ipv4[each.key]
  id       = each.value.ipv4_id
}

import {
  for_each = local.legacy_servers
  to       = hcloud_primary_ip.legacy_ipv6[each.key]
  id       = each.value.ipv6_id
}

# k3s control plane node.
resource "hcloud_primary_ip" "control_plane_ipv4" {
  name        = "primary_ip-158447567"
  type        = "ipv4"
  location    = "fsn1"
  auto_delete = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "hcloud_primary_ip" "control_plane_ipv6" {
  name        = "primary_ip-158447568"
  type        = "ipv6"
  location    = "fsn1"
  auto_delete = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "hcloud_server" "control_plane" {
  name        = "k3s-cp-node"
  server_type = "cx33"
  image       = "debian-12"
  location    = "fsn1"
  ssh_keys    = [hcloud_ssh_key.marco.id]

  public_net {
    ipv4_enabled = true
    ipv4         = hcloud_primary_ip.control_plane_ipv4.id
    ipv6_enabled = true
    ipv6         = hcloud_primary_ip.control_plane_ipv6.id
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [ssh_keys, image, user_data]
  }
}

import {
  to = hcloud_server.control_plane
  id = "173154994"
}

import {
  to = hcloud_primary_ip.control_plane_ipv4
  id = "158447567"
}

import {
  to = hcloud_primary_ip.control_plane_ipv6
  id = "158447568"
}
