You are a technical writer creating public-facing documentation for the
MTO Dependencies Operator — a Kubernetes Helm-based operator that manages
infrastructure dependencies via Custom Resources (CRs).

The operator defines 7 CRDs under the API group
`dependencies.tenantoperator.stakater.com/v1alpha1`. Each CR maps to an
embedded Helm chart; the CR's `.spec` accepts the chart's values directly
(enabled by `x-kubernetes-preserve-unknown-fields: true`).

---

## Documentation Structure

The documentation lives under a sidebar menu item called
**"MTO Dependencies Operator"** with the following pages:

### Page 1: Overview
- One paragraph explaining what the operator does, who it's for, and why
  it exists (manages infra dependencies for the Multi-Tenant Operator
  ecosystem).
- List the 7 components it manages (Dex, Postgres, Prometheus,
  KubeStateMetrics, OpenCost, DexConfigOperator, FinOpsOperator).
- Briefly explain the pattern: users create a CR, the operator deploys
  the corresponding Helm chart using the CR's `.spec` as chart values.

### Page 2: CR Reference
A single reference page covering all 7 CRs. For each CR include:

1. **Kind & API Version** — e.g. `Kind: Dex`, `apiVersion: dependencies.tenantoperator.stakater.com/v1alpha1`
2. **One-line purpose.**
3. **Key Configuration Fields** — a short table (Field | Type | Default |
   Description) covering only the most important user-facing settings.
   Do NOT exhaustively list every Helm value. For the full list of
   supported values, link to the upstream chart documentation:
   - Dex: https://github.com/dexidp/helm-charts
   - PostgreSQL: https://github.com/bitnami/charts/tree/main/bitnami/postgresql
   - Prometheus: https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus
   - Kube State Metrics: https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-state-metrics
   - OpenCost: https://github.com/opencost/opencost-helm-chart
   - DexConfigOperator & FinOpsOperator: Stakater internal charts (no public upstream)
4. **Notes** — 1-2 bullets max on gotchas or prerequisites.

### Page 3+: Deployment Guides (one per component)
Each guide is a separate page titled "Deploying <Component>". Include:

1. **Prerequisites** — namespace, secrets, or dependencies needed before
   applying the CR (e.g. Postgres needs a secret for credentials, OpenCost
   needs a running Prometheus).
2. **Minimal Example** — the simplest possible CR YAML that produces a
   working deployment. Copy-paste ready.
3. **Common Customizations** — 2-3 short YAML snippets showing how to
   tweak the most-asked-about settings (e.g. enabling persistence,
   adding ingress, scaling replicas). Keep each snippet partial (just the
   relevant `.spec` keys, not the full CR).
4. **Verification** — a `kubectl` one-liner to confirm the component is
   running (e.g. `kubectl get pods -l app.kubernetes.io/name=dex`).
5. **Further Reading** — link to the upstream Helm chart docs for the
   full values reference.

---

## CR Details for the Writer

#### 1. Dex
- Purpose: OpenID Connect identity provider
- Helm chart: dex (app v2.44.0)
- Key areas: `config` (issuer, storage, connectors, staticClients), `image`,
  `service`, `ingress`, `rbac`, `resources`, `replicaCount`
- Minimal example:
    apiVersion: dependencies.tenantoperator.stakater.com/v1alpha1
    kind: Dex
    metadata:
      name: dex
    spec:
      replicaCount: 1
      config:
        issuer: https://dex.example.com
        storage:
          type: kubernetes
          config:
            inCluster: true
      service:
        type: ClusterIP
        ports:
          http:
            port: 5556

#### 2. Postgres
- Purpose: Production-ready PostgreSQL (Bitnami chart)
- Helm chart: postgresql (app v17.6.0)
- Key areas: `architecture` (standalone/replication), `auth` (credentials,
  existingSecret), `primary.persistence`, `primary.resources`,
  `readReplicas`, `metrics`, `backup`
- Defaults: architecture=standalone, persistence.size=8Gi,
  readReplicas.replicaCount=0

#### 3. Prometheus
- Purpose: Metrics collection, storage, and alerting
- Helm chart: prometheus (community chart)
- Key areas: `server` (retention, persistentVolume, resources),
  `alertmanager.enabled`, `prometheus-node-exporter.enabled`,
  `kube-state-metrics.enabled`, `serverFiles`
- Defaults: retention=15d, persistentVolume.size=8Gi

#### 4. KubeStateMetrics
- Purpose: Exports Kubernetes object metrics for Prometheus
- Helm chart: kube-state-metrics (community chart)
- Key areas: `replicas`, `collectors` (list of k8s object types), `rbac`,
  `prometheus.monitor`, `resources`
- Defaults: replicas=1, 24 collectors enabled

#### 5. OpenCost
- Purpose: Kubernetes cost monitoring and FinOps visibility
- Helm chart: opencost (app v1.117.3)
- Key areas: `opencost.exporter` (replicas, resources, defaultClusterId),
  `opencost.prometheus` (internal/external), `opencost.ui` (enabled, port),
  `opencost.customPricing`
- Defaults: ui.enabled=true, ui.uiPort=9090

#### 6. DexConfigOperator
- Purpose: Dynamically manages Dex connectors and OAuth client configs
- Helm chart: dex-config-operator (Stakater custom)
- Key areas: `controllerManager.manager` (image, env, resources),
  `controllerManager.replicas`, `kubernetesClusterDomain`
- Defaults: replicas=1, manager.resources.limits={cpu:500m, memory:128Mi}

#### 7. FinOpsOperator
- Purpose: MTO-specific cost management platform
- Helm chart: finops-operator (Stakater custom, v0.1.14)
- Key areas: `controllerManager.manager` (image, env, resources),
  `finops-gateway` (container, replicas, service),
  `kubernetesClusterDomain`

---

## Formatting Rules
- Each page should be a separate markdown file.
- YAML examples must be complete (apiVersion through spec) and
  copy-paste ready in full examples; partial snippets are fine for
  "Common Customizations" sections.
- Keep the CR Reference page concise — lean on upstream chart docs links
  instead of duplicating field lists.
- Keep each Deployment Guide under 500 words.
- End the CR Reference page with a "Common Patterns" note that all CRs
  support `resources`, `nodeSelector`, `tolerations`, `affinity`, and
  `podAnnotations` since they pass through to standard Helm values.
