# Upgrading CRDs

## Why this page exists

Helm applies a chart's `crds/` directory only on `helm install`, never on `helm upgrade`. The operator reconciles each CR by running `helm upgrade` on an existing release, so any CRD parked in `crds/` was frozen at whatever shipped the day the release was first installed. Bumping a chart version delivered a new controller image against a stale CRD schema.

The CRDs for the three operator dependencies now live in `templates/` instead, so every reconcile applies them:

| Chart | CRDs |
|-------|------|
| `finops-operator` | `costjobs`, `finopsproviders`, `offerings`, `pricebooks`, `subscriptions` (`.finops.stakater.com`) |
| `dex-config-operator` | `clients`, `connectors`, `dexconfigs`, `localusers` (`.auth.stakater.com`) |
| `template-operator-v2` | `templates`, `templateinstances` (`.templates.v2.stakater.com`) |

Each carries `helm.sh/resource-policy: keep`, so deleting the CR uninstalls the release without dropping the CRD and garbage collecting every custom resource under it.

## One-time migration on existing clusters

CRDs created by Helm's CRD installer carry no Helm ownership metadata. The first upgrade after this change sees them as unowned and refuses to adopt them:

```
Error: UPGRADE FAILED: rendered manifests contain a resource that already exists.
Unable to continue with update: CustomResourceDefinition "..." exists and cannot be
imported into the current release: invalid ownership metadata
```

Stamp the ownership metadata once, before upgrading. The release name is the CR name and the release namespace is the CR namespace, so both can be read off the CRs themselves.

Check what needs adopting first. Anything printed without `Helm` is not yet owned:

```bash
kubectl get crd \
  -l '!app.kubernetes.io/managed-by' \
  -o custom-columns=NAME:.metadata.name \
  | grep -E 'finops.stakater.com|auth.stakater.com|templates.v2.stakater.com'
```

Then run the adoption. It derives each release from its CR, skips CRDs that are not installed, and is safe to re-run:

```bash
#!/usr/bin/env bash
set -euo pipefail

adopt() {
  local cr_kind=$1; shift
  local crds=("$@")
  local name ns
  while read -r name ns; do
    [ -z "$name" ] && continue
    echo "==> $cr_kind $ns/$name"
    for crd in "${crds[@]}"; do
      kubectl get crd "$crd" >/dev/null 2>&1 || { echo "    skip $crd (not present)"; continue; }
      kubectl label crd "$crd" app.kubernetes.io/managed-by=Helm --overwrite
      kubectl annotate crd "$crd" \
        meta.helm.sh/release-name="$name" \
        meta.helm.sh/release-namespace="$ns" --overwrite
    done
  done < <(kubectl get "$cr_kind" -A \
    -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.metadata.namespace}{"\n"}{end}' 2>/dev/null)
}

adopt finopsoperators \
  costjobs.finops.stakater.com finopsproviders.finops.stakater.com \
  offerings.finops.stakater.com pricebooks.finops.stakater.com \
  subscriptions.finops.stakater.com

adopt dexconfigoperators \
  clients.auth.stakater.com connectors.auth.stakater.com \
  dexconfigs.auth.stakater.com localusers.auth.stakater.com

adopt templateoperatorv2s \
  templates.templates.v2.stakater.com templateinstances.templates.v2.stakater.com
```

Verify before upgrading. Every CRD should show `Helm` plus the owning release:

```bash
kubectl get crd -o custom-columns=\
NAME:.metadata.name,\
OWNER:.metadata.labels.app\\.kubernetes\\.io/managed-by,\
RELEASE:.metadata.annotations.meta\\.helm\\.sh/release-name \
  | grep -E 'finops.stakater.com|auth.stakater.com|templates.v2.stakater.com'
```

If a release is stuck because the reconcile already failed, the operator retries on its own once the metadata is in place. No restart needed.

Clusters installing these dependencies for the first time need nothing.

## Automatic adoption

The manual script above is only needed for CRs whose names differ from the ones MTO creates. For those, the `adopt-crds` initContainer on the operator deployment ([config/manager/manager.yaml](../config/manager/manager.yaml)) stamps the same ownership metadata on every pod start. It finishes before helm-operator starts, so before any install or upgrade runs Helm's ownership check.

It uses a fixed map of release name to CRD, matching the CR names MTO creates, with the operator's own namespace as the release namespace:

| Release | CRDs |
|---------|------|
| `dex-config-operator` | `.auth.stakater.com` |
| `tenant-operator-finops` | `.finops.stakater.com` |
| `tenant-operator-template-operator-v2` | `.templates.v2.stakater.com` |

CRDs not installed yet are skipped. Any other API error fails the init container, so the pod restarts and retries.

A Helm `pre-install,pre-upgrade` hook cannot do this job: helm-operator checks ownership while building the release, before any hook runs, so the hook never fires in time.

A chart resync that adds a CRD needs no entry here. A new CRD was never created unowned, so Helm creates and owns it.

## Adding or resyncing a chart

`make resync-charts` promotes `crds/` into `templates/` automatically via the `promote-crds` helper in the Makefile. It also escapes `{{` in the CRD files, because CRD descriptions may document Go template syntax that Helm would otherwise try to evaluate.

A chart vendored by hand needs the same treatment. `make lint` fails if any chart under `helm-charts/` still ships a `crds/` directory.
