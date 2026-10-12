# Upgrading CRDs

## How CRDs reach the cluster

Three vendored charts ship CRDs:

| Chart | CRDs |
|-------|------|
| `finops-operator` | `costjobs`, `finopsproviders`, `offerings`, `pricebooks`, `subscriptions` (`.finops.stakater.com`) |
| `dex-config-operator` | `clients`, `connectors`, `dexconfigs`, `localusers` (`.auth.stakater.com`) |
| `template-operator-v2` | `templates`, `templateinstances` (`.templates.v2.stakater.com`) |

They live in each chart's `crds/` directory, and Helm is not what keeps them current. Helm applies `crds/` only on `helm install`, never on `helm upgrade`, and the operator reconciles every CR with `helm upgrade`. Instead, the `apply-crds` initContainer on the operator deployment ([config/manager/manager.yaml](../config/manager/manager.yaml)) server-side applies a chart's `crds/*.yaml` on each pod start, with `force=true` so it wins any field conflict. A chart bump ships in a new operator image, the new pod applies the new schema before helm-operator starts, and the releases never see the CRDs at all.

CRDs are applied only for charts that have a CR on the cluster, so a cluster that never enables FinOps carries no finops CRDs. The initContainer lists each of the three kinds and skips a chart whose list is empty. A CR created later gets its CRDs from Helm on install, at the chart version in that image, and the next pod start brings them current. The kind to chart table lives in the initContainer; `make lint` fails if a chart ships CRDs without an entry.

The initContainer fails the pod on any apply or list error. That is deliberate: helm-operator must not run against CRDs in an unknown state.

Nothing in this depends on where the operator pod runs or where the CRs live. The operator supports only the `AllNamespaces` install mode, so on OpenShift it is routinely in `openshift-operators` while MTO and its CRs are in `multi-tenant-operator`.

## Why Helm must not own the CRDs

MDO 0.0.14 and 0.0.15 rendered the CRDs from `templates/` so that upgrades would apply them. That put Helm's ownership check in the path: a release can only install over an existing resource whose `meta.helm.sh/release-name` and `meta.helm.sh/release-namespace` annotations match the release. An initContainer stamped those annotations using the operator pod's own namespace, which is wrong whenever the operator and the CRs are in different namespaces, and every install then failed with:

```
Unable to continue with install: CustomResourceDefinition "clients.auth.stakater.com" in namespace ""
exists and cannot be imported into the current release: invalid ownership metadata; annotation
validation error: key "meta.helm.sh/release-namespace" must equal "multi-tenant-operator":
current value is "openshift-operators"
```

The ownership check runs before any Helm hook, so no hook can fix it, and the correct release namespace is unknowable at pod start. Taking the CRDs out of Helm's hands removes the problem rather than patching around it.

## Migration safety

Deleting a CRD garbage collects every instance under it, so the upgrade from 0.0.14 or 0.0.15 must never let Helm delete one. On the first `helm upgrade` after this change, the CRDs are present in the old release manifest and absent from the new one, so Helm considers deleting them. It first reads the live object and skips the delete when it carries `helm.sh/resource-policy: keep`.

Every `crds/*.yaml` carries that annotation, and the initContainer applies it before helm-operator runs, so the annotation is on every live CRD before the first upgrade can happen. The templates-era CRDs already had it, since the templates included it. helm-operator logs the outcome on that first reconcile:

```
Skipping delete of "costjobs.finops.stakater.com" due to annotation [helm.sh/resource-policy=keep]
```

The deployment uses the `Recreate` strategy so the old pod, still rendering CRDs from its templates, can never reconcile after the new pod has applied the newer schema.

Clusters on 0.0.13 or older never had Helm-owned CRDs. The initContainer updates their schema and nothing else changes.

The `meta.helm.sh/*` annotations and the `app.kubernetes.io/managed-by: Helm` label that 0.0.14 and 0.0.15 left on the CRDs are inert now and are not removed.

`tests/integration/test_crd_upgrade.sh` covers this path: a stale CRD and an instance exist before the operator pod starts, then a FinOpsOperator must still install, the instance must survive, and the CRD must carry the new schema.

## Adding or resyncing a chart

`make resync-charts` leaves `crds/` in place and runs the `keep-crds` helper in the Makefile, which adds `helm.sh/resource-policy: keep` to any CRD file that lacks it. A chart vendored by hand needs the same treatment.

`make lint` fails if a chart templates a CRD, or if any `crds/*.yaml` is not a single document with exactly one `metadata.name` at two-space indent and the keep annotation. The initContainer reads the CRD name from that line to build the apply URL.
