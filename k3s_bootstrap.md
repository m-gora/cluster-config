# k3s bootstrap

## Control plane (one-time, manual)
The control plane cannot be rebuilt (scarce cx33 instance type, stable IP),
so it does not use cloud-init. tofu renders the install script instead:

```sh
tofu output -raw control_plane_bootstrap | ssh root@$(tofu output -raw control_plane_public_ipv4) bash
```

The rendered script:
- pins the hostname to the server name (required by the Hetzner CCM),
- writes `/etc/rancher/k3s/config.yaml` (embedded etcd via `cluster-init`,
  node IP `10.0.1.10` on the private network, external cloud provider for
  the CCM, secrets encryption, server + agent tokens),
- installs the pinned k3s release, waits for the node to become Ready.

Tokens live in the encrypted OpenTofu state. The output is marked
sensitive; they are only rendered through `-raw`.

The API dials TLS over the public IP plus `var.k3s_api_domain` (--tls-san).

## Workers (future)
Created through tofu with cloud-init user_data that joins the cluster at
https://10.0.1.10:6443 using the agent token.
