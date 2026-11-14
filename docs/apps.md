# Apps: structure and how to add one

The `k8s/` tree is split into three layers, each reconciled by its own Flux
`Kustomization` (declared in `k8s/flux-system/gotk-sync.yaml`, which is
self-referential — the `flux-system` layer applies it, so Flux CR changes
reconcile from git like everything else):

```
k8s/
  flux-system/    Flux's own components + the layer CRs (bootstrap pattern)
  infra/          platform services: networking, DNS, TLS, storage, postgres
  apps/           actual app deployments
```

- `apps` has `dependsOn: infra`, so platform changes apply first and app
  churn never blocks a platform sync (and vice versa).
- Each directory needs a `kustomization.yaml` listing its manifests (or
  subdirectories). Flux would auto-generate one for plain YAML dirs, but the
  explicit files make file additions deliberate and apply order controlled.

## The three app shapes (`k8s/apps/<name>/`)

1. **Public Helm chart** — `HelmRepository` + `HelmRelease` manifests in the
   app dir (see `k8s/infra/cert-manager` for the pattern). Renovate's `flux`
   manager bumps chart versions.

2. **Public container image, no chart** — plain `StatefulSet`/`Deployment` +
   `Service` (+ `HTTPRoute`) manifests committed here (see
   `k8s/apps/foundryvtt`). Renovate's `kubernetes` manager bumps the image
   tag. Pin a concrete version tag, never a moving one.

3. **Own app repos** — a pointer only: a `GitRepository` (public https URL)
   and a `Kustomization` whose `sourceRef` targets it and whose `path` points
   at the app repo's `deploy/` directory. Both CRs live in `flux-system`
   namespace even though the workload lands elsewhere. The app repo owns its
   manifests (`kustomization.yaml` + workload YAMLs) and its own Renovate
   config; its image tags are bumped there, not here.

## Conventions

- Namespace: each app declares its own `Namespace` in its manifests and
  namespaces all its resources. Flux CRs (sources, Kustomizations) always go
  to `flux-system`.
- Secrets are SOPS-encrypted Secret manifests committed next to the
  consumer (see `secret-*.yaml` files; config in `.sops.yaml`, age key on
  the cluster as `flux-system/sops-age`, locally at
  `~/.config/sops/age/keys.txt` via `SOPS_AGE_KEY_FILE` in `.envrc`).
  Edit with `sops <file>`, create by writing the Secret with real values
  then `sops -e -i <file>`. The `infra` and `apps` Flux Kustomizations
  carry the decryption spec — a new layer needs it too. Back up the age
  key: there is no recovery without it.
- Ingress: `HTTPRoute` in the app namespace, `parentRef` to the `cluster`
  Gateway in `kube-system` (`sectionName: websecure`), host under
  `*.cloud.marcodoes.tech`, and the `externaldns.kubernetes.io/enabled=true`
  label so external-dns creates the record.
- Storage: stateful apps use `StatefulSet` with `volumeClaimTemplates` on
  `storageClassName: hcloud-volumes` (see postgres/foundryvtt). The PVC comes
  from the template and cannot be renamed later — get size right up front
  (expansion works). Deleting the StatefulSet keeps the PVC.

## Checklist for a new app

1. Create `k8s/apps/<name>/` with manifests + `kustomization.yaml` (or a
   pointer pair for shape 3).
2. Add `- <name>` to `k8s/apps/kustomization.yaml`.
3. List every new file in the app's `kustomization.yaml`.
4. Create any secrets: write the Secret manifest with real values in the
   app dir, `sops -e -i` it, add it to the app's `kustomization.yaml`.
5. `kustomize build k8s/apps`, push, then check `flux get kustomizations`
   (the `apps` sync turns Ready when all app resources are healthy).

## Migrating Foundry VTT from the old docker compose host

The old stack (nginx-proxy, acme-companion, foundry) is replaced by the
cluster's Gateway + cert-manager + the `foundryvtt` app. Cutover:

1. **Fill the secret**: `source .envrc && sops k8s/apps/foundryvtt/secret-foundryvtt.yaml`
   — replace the placeholder `username`/`password` (foundryvtt.com account,
   used to download the distribution) and confirm `admin-key` matches the
   old compose value.
2. On the old host: `tar czf foundry-data.tgz foundry-data` and copy it off
   the host (the data volume is mounted at `/data` in the container; the
   Foundry license lives inside it — no license env needed).
3. Push the commit. Flux deploys the StatefulSet; the pod starts with the
   placeholder admin key (or crashloops if the secret was left as-is) —
   either way the PVC `data-foundryvtt-0` is created.
4. Load the data: `kubectl -n foundryvtt scale statefulset foundry13 --replicas=0`,
   run a helper pod mounting that PVC (`data-foundry13-0`), `kubectl cp`
   the tarball in and untar it preserving ownership (the image runs as
   uid 1000), delete the helper, scale back to 1.
5. **DNS**: the HTTPRoute serves `vtt.cloud.marcodoes.tech` under the
   existing wildcard. The old `vtt.marcodoes.tech` is handled by a
   Cloudflare edge redirect to the new host (set up in the Cloudflare
   console) — no record or Gateway listener needed on the cluster side.
6. After verifying, stop the old compose stack.
