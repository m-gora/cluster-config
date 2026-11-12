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
  }

  # Existing Hetzner servers that were rebuilt into k3s workers. The former
  # ubuntu-4gb-fsn1-1 (server id 167475168) is "k3s-worker-1": renamed and
  # re-imaged via a manual `hcloud server rebuild`, so server id and primary
  # IPs are preserved (a replace would orphan them). state was relocated with
  # `moved` blocks, not re-imported.
  k3s_workers = {
    "k3s-worker-1" = {
      id          = 167475168
      server_type = "cx23"
      image       = "debian-12"
      location    = "fsn1"
      ipv4_id     = 151687654
      ipv6_id     = 151687655
    }
  }

  server_labels = {
    "k3s-cp-node"       = { cluster = "k3s", role = "control-plane" }
    "k3s-worker-1"      = { cluster = "k3s", role = "worker" }
    "ubuntu-4gb-nbg1-1" = { cluster = "k3s", role = "migration" }
  }
}

resource "hcloud_primary_ip" "legacy_ipv4" {
  for_each = local.legacy_servers

  name        = "primary_ip-${each.value.ipv4_id}"
  type        = "ipv4"
  location    = each.value.location
  auto_delete = false

  # Without this, tofu would plan assignee_id -> null (the config doesn't
  # declare an assignee), and the provider's Update would then issue an
  # API Unassign, detaching the IP from the running server.
  delete_protection = true

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [assignee_id, assignee_type]
  }
}

resource "hcloud_primary_ip" "legacy_ipv6" {
  for_each = local.legacy_servers

  name        = "primary_ip-${each.value.ipv6_id}"
  type        = "ipv6"
  location    = each.value.location
  auto_delete = false

  delete_protection = true

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [assignee_id, assignee_type]
  }
}

resource "hcloud_primary_ip" "worker_ipv4" {
  for_each = local.k3s_workers

  name        = "primary_ip-${each.value.ipv4_id}"
  type        = "ipv4"
  location    = each.value.location
  auto_delete = false

  delete_protection = true

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [assignee_id, assignee_type]
  }
}

resource "hcloud_primary_ip" "worker_ipv6" {
  for_each = local.k3s_workers

  name        = "primary_ip-${each.value.ipv6_id}"
  type        = "ipv6"
  location    = each.value.location
  auto_delete = false

  delete_protection = true

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [assignee_id, assignee_type]
  }
}

# The fsn1 server was restructured from the legacy map into its own k3s
# worker map (rename to k3s-worker-1, re-image to debian-12 via manual
# rebuild). moved keeps the existing state objects - no destroy/create.
moved {
  from = hcloud_server.legacy["ubuntu-4gb-fsn1-1"]
  to   = hcloud_server.worker["k3s-worker-1"]
}

moved {
  from = hcloud_primary_ip.legacy_ipv4["ubuntu-4gb-fsn1-1"]
  to   = hcloud_primary_ip.worker_ipv4["k3s-worker-1"]
}

moved {
  from = hcloud_primary_ip.legacy_ipv6["ubuntu-4gb-fsn1-1"]
  to   = hcloud_primary_ip.worker_ipv6["k3s-worker-1"]
}

resource "hcloud_server" "worker" {
  for_each = local.k3s_workers

  name        = each.key
  server_type = each.value.server_type
  image       = each.value.image
  location    = each.value.location
  ssh_keys    = [hcloud_ssh_key.marco.id]
  labels      = local.server_labels[each.key]

  # Same alias_ips = [] workaround as on the control plane (#650). Hot attach
  # happens during apply; the worker is up and serving until the rebuild.
  network {
    subnet_id = hcloud_network_subnet.k3s.id
    ip        = local.k3s_nodes[each.key].private_ip
    alias_ips = []
  }

  # The Hetzner API requires delete and rebuild protection to have the same
  # value (change_protection rejects mixed settings). Both are switched off
  # for the duration of the rebuild; both are set back to true once the node
  # has joined the cluster. prevent_destroy in the lifecycle still blocks
  # tofu from ever destroying this resource.
  delete_protection  = false
  rebuild_protection = false

  depends_on = [hcloud_network_subnet.k3s]

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [ssh_keys, image, user_data]
  }
}
resource "hcloud_server" "legacy" {
  for_each = local.legacy_servers

  name        = each.key
  server_type = each.value.server_type
  image       = each.value.image
  location    = each.value.location
  ssh_keys    = [hcloud_ssh_key.marco.id]
  labels      = local.server_labels[each.key]

  # No public_net block: the server resource's DiffSuppressFunc ignores the
  # diff when the block is unset, so tofu doesn't try to re-link the primary
  # IPs (which would power off the server). The IPs are managed as
  # independent hcloud_primary_ip resources instead.

  delete_protection  = true
  rebuild_protection = true

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

  delete_protection = true

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [assignee_id, assignee_type]
  }
}

resource "hcloud_primary_ip" "control_plane_ipv6" {
  name        = "primary_ip-158447568"
  type        = "ipv6"
  location    = "fsn1"
  auto_delete = false

  delete_protection = true

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [assignee_id, assignee_type]
  }
}

resource "hcloud_server" "control_plane" {
  name        = "k3s-cp-node"
  server_type = "cx33"
  image       = "debian-12"
  location    = "fsn1"
  ssh_keys    = [hcloud_ssh_key.marco.id]
  labels      = local.server_labels["k3s-cp-node"]

  # Private network for k3s node-to-node traffic. Hot attach is safe on a
  # running server; the network interface comes up via DHCP. alias_ips = []
  # works around the provider's repeated detach/attach bug (#650).
  network {
    subnet_id = hcloud_network_subnet.k3s.id
    ip        = local.k3s_nodes["k3s-cp-node"].private_ip
    alias_ips = []
  }

  delete_protection  = true
  rebuild_protection = true

  depends_on = [hcloud_network_subnet.k3s]

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
