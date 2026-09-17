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

## The adoption hook

The manual script above is only needed on clusters upgraded before the hook shipped. Each chart that ships CRDs now carries `templates/crd-adoption-job.yaml`, a `pre-install,pre-upgrade` hook that stamps the same ownership metadata before Helm renders the release.

The job is generated, never hand edited. `make gen-crd-adoption-jobs` writes it from the CRDs a chart ships, `make lint-crd-adoption-jobs` fails if a copy is stale, and `CRD_ADOPTION_IMAGE` in the Makefile sets the image it runs.

That image is the operator image. It needs only `sh` and `curl`, and its numeric `USER 1001` is what lets `runAsNonRoot` be verified without pinning a UID -- pinning one would be rejected by OpenShift's `restricted-v2` SCC, which assigns a UID from the namespace range instead.

Because the hook starts a pod in the release namespace, a private image needs a pull secret *in that namespace*. A secret sitting elsewhere in the cluster is not enough, and neither is one in the namespace alone: Kubernetes only uses credentials named by the pod or its ServiceAccount. Without them the pod sits in `ImagePullBackOff` until `activeDeadlineSeconds` expires and the release fails pre-install with `job <release>-crd-adoption failed: DeadlineExceeded`.

`CRD_ADOPTION_IMAGE` tracks `IMG`, and `docker-build` regenerates the charts before the Dockerfile copies `helm-charts/` into the image. So the hook always pulls the exact image it ships inside: a snapshot build bakes its own `-SNAPSHOT-<sha>` tag, and a release build bakes its release tag. Nothing has to wait for `v$(VERSION)` to be published.

Two consequences follow. The `crdAdoption.image` in a committed `values.yaml` is only whatever the last local build stamped, so `make lint-crd-adoption-jobs` deliberately ignores that line while still comparing the CRD list and everything else. And `make docker-build` leaves those three files modified in your working tree; rerun `make gen-crd-adoption-jobs` with no `IMG` set to restore them.

Per release overrides live under `crdAdoption` in the chart values:

| Key | Default | Purpose |
|-----|---------|---------|
| `enabled` | `true` | Set to `false` to skip the hook |
| `image` | the operator image, stamped from `IMG` at build time | Image to run, needs only `sh` and `curl` |
| `imagePullPolicy` | `IfNotPresent` | |
| `imagePullSecrets` | falls back to the chart-wide `imagePullSecrets` | Credentials for a private image, needed in the release namespace |

## Adding or resyncing a chart

`make resync-charts` promotes `crds/` into `templates/` automatically via the `promote-crds` helper in the Makefile. It also escapes `{{` in the CRD files, because CRD descriptions may document Go template syntax that Helm would otherwise try to evaluate.

A chart vendored by hand needs the same treatment. `make lint` fails if any chart under `helm-charts/` still ships a `crds/` directory.
