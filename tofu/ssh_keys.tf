resource "hcloud_ssh_key" "marco" {
  name       = "marco@Mac.box"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMvHveK+lpFZlVxAJ5GZiwdFJ+edRNa3pJmR+WSW7qNY"
}

import {
  to = hcloud_ssh_key.marco
  id = "104261435"
}
