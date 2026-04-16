# Custom Resource Reference

All Custom Resources belong to the API group `dependencies.tenantoperator.stakater.com/v1alpha1`. Each CR's `.spec` is passed directly as Helm values to the underlying chart, so any value the chart supports can be set in the CR spec.

---

## Dex

**Kind:** `Dex` | OpenID Connect (OIDC) identity provider with pluggable connectors.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `replicaCount` | int | `1` | Number of Dex replicas |
| `config` | object | `{}` | Dex configuration (issuer, storage, connectors, staticClients) |
| `config.issuer` | string | — | The external URL where Dex is reachable |
| `config.storage` | object | — | Backend storage configuration (kubernetes, sqlite3, postgres, etc.) |
| `config.connectors` | list | — | Upstream identity provider connectors (OIDC, LDAP, GitHub, etc.) |
| `config.staticClients` | list | — | OAuth2 client applications |
| `ingress.enabled` | bool | `false` | Enable ingress for Dex |
| `rbac.create` | bool | `true` | Create RBAC resources |
| `rbac.createClusterScoped` | bool | `true` | Create cluster-scoped RBAC |

> For all supported values, see the [Dex Helm chart documentation](https://github.com/dexidp/helm-charts).

---

## Postgres

**Kind:** `Postgres` | Production-ready PostgreSQL database (Bitnami chart, app v17.6.0).

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `architecture` | string | `standalone` | `standalone` or `replication` |
| `auth.postgresPassword` | string | — | Password for the `postgres` admin user |
| `auth.username` | string | — | Custom user to create |
| `auth.password` | string | — | Password for the custom user |
| `auth.database` | string | — | Default database to create |
| `auth.existingSecret` | string | — | Use an existing Secret for credentials |
| `primary.persistence.enabled` | bool | `true` | Enable persistent storage |
| `primary.persistence.size` | string | `8Gi` | PVC size for the primary instance |
| `primary.resources` | object | `{}` | CPU/memory requests and limits |
| `readReplicas.replicaCount` | int | `1` | Number of read replicas (only used when `architecture: replication`) |
| `metrics.enabled` | bool | `false` | Enable Prometheus metrics exporter |

> For all supported values, see the [Bitnami PostgreSQL chart documentation](https://github.com/bitnami/charts/tree/main/bitnami/postgresql).

---

## Prometheus

**Kind:** `Prometheus` | Monitoring and alerting system with time-series database.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `server.replicaCount` | int | `1` | Number of Prometheus server replicas |
| `server.retention` | string | `15d` | Data retention period |
| `server.persistentVolume.enabled` | bool | `true` | Enable persistent storage for the server |
| `server.persistentVolume.size` | string | `8Gi` | PVC size for the server |
| `server.resources` | object | `{}` | CPU/memory requests and limits |
| `alertmanager.enabled` | bool | `true` | Deploy Alertmanager |
| `kube-state-metrics.enabled` | bool | `true` | Deploy Kube State Metrics as a sub-chart |
| `prometheus-node-exporter.enabled` | bool | `true` | Deploy Node Exporter as a sub-chart |
| `prometheus-pushgateway.enabled` | bool | `true` | Deploy Pushgateway |
| `serverFiles` | object | — | Prometheus configuration files (alerting rules, scrape configs) |

> For all supported values, see the [Prometheus community chart documentation](https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus).

---

## KubeStateMetrics

**Kind:** `KubeStateMetrics` | Exports Kubernetes object metrics for Prometheus.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `replicas` | int | `1` | Number of replicas |
| `collectors` | list | 28 resource types | Kubernetes object types to collect metrics for |
| `rbac.create` | bool | `true` | Create RBAC resources |
| `rbac.useClusterRole` | bool | `true` | Use a ClusterRole (required to read cluster-wide resources) |
| `prometheus.monitor.enabled` | bool | `false` | Create a ServiceMonitor for Prometheus Operator |
| `resources` | object | `{}` | CPU/memory requests and limits |

> For all supported values, see the [Kube State Metrics chart documentation](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-state-metrics).

---

## OpenCost

**Kind:** `OpenCost` | Kubernetes cost monitoring and FinOps visibility (app v1.117.3).

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `opencost.exporter.replicas` | int | `1` | Number of exporter replicas |
| `opencost.exporter.defaultClusterId` | string | `default-cluster` | Cluster identifier for cost data |
| `opencost.prometheus.internal.enabled` | bool | `true` | Use an in-cluster Prometheus instance |
| `opencost.prometheus.internal.serviceName` | string | `prometheus-server` | Service name of the Prometheus server |
| `opencost.prometheus.internal.namespaceName` | string | `prometheus-system` | Namespace of the Prometheus server |
| `opencost.prometheus.external.enabled` | bool | `false` | Use an external Prometheus URL |
| `opencost.prometheus.external.url` | string | — | External Prometheus URL |
| `opencost.ui.enabled` | bool | `true` | Enable the OpenCost web UI |
| `opencost.ui.uiPort` | int | `9090` | Port for the web UI |
| `opencost.customPricing.enabled` | bool | `false` | Enable custom cost model pricing |

> For all supported values, see the [OpenCost Helm chart documentation](https://github.com/opencost/opencost-helm-chart).

---

## DexConfigOperator

**Kind:** `DexConfigOperator` | Dynamically manages Dex connectors and OAuth client configurations.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `controllerManager.replicas` | int | `1` | Number of operator replicas |
| `controllerManager.manager.image.repository` | string | `ghcr.io/stakater/public/dex-config-operator` | Container image |
| `controllerManager.manager.image.tag` | string | `v0.0.5` | Image tag |
| `controllerManager.manager.env.dexNamespace` | string | `dex` | Namespace where Dex is deployed |
| `controllerManager.manager.resources` | object | limits: 500m/128Mi | CPU/memory requests and limits |
| `kubernetesClusterDomain` | string | `cluster.local` | Kubernetes cluster domain |

> This is a Stakater-managed chart. No public upstream documentation is available.

---

## FinOpsOperator

**Kind:** `FinOpsOperator` | MTO-specific cost monitoring and management platform.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `controllerManager.replicas` | int | `1` | Number of operator replicas |
| `controllerManager.manager.image.repository` | string | `ghcr.io/stakater/public/finops-operator` | Container image |
| `controllerManager.manager.image.tag` | string | `v0.1.1` | Image tag |
| `controllerManager.manager.env.opencostDeploymentName` | string | `finops-operator-opencost` | Name of the OpenCost deployment |
| `controllerManager.manager.env.opencostDeploymentNamespace` | string | `finops-operator-system` | Namespace of the OpenCost deployment |
| `finopsGatewayGateway.replicas` | int | `1` | Number of gateway replicas |
| `finopsGatewayGateway.finopsGatewayContainer.env.enableAuth` | string | `"false"` | Enable authentication on the gateway |
| `finopsGatewayGateway.finopsGatewayContainer.env.port` | string | `"8080"` | Gateway listen port |
| `kubernetesClusterDomain` | string | `cluster.local` | Kubernetes cluster domain |

> This is a Stakater-managed chart. No public upstream documentation is available.

---

## Common Patterns

All CRs support standard Helm value fields that are passed through to the underlying chart:

- `resources` — CPU and memory requests/limits
- `nodeSelector` — Schedule pods on specific nodes
- `tolerations` — Tolerate specific node taints
- `affinity` — Advanced pod scheduling rules
- `podAnnotations` — Custom annotations on pods
