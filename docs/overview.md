# MTO Dependencies Operator

The MTO Dependencies Operator is a Kubernetes operator that manages common infrastructure dependencies required by the [Multi-Tenant Operator](https://www.stakater.com/mto) (MTO) ecosystem. Instead of manually installing and upgrading multiple Helm releases, platform teams create declarative Custom Resources and the operator handles the full lifecycle — install, upgrade, and deletion — automatically.

## Managed Components

The operator manages 7 infrastructure components:

| Component | CR Kind | Purpose |
|-----------|---------|---------|
| Dex | `Dex` | OpenID Connect identity provider |
| PostgreSQL | `Postgres` | Production-ready relational database |
| Prometheus | `Prometheus` | Metrics collection, storage, and alerting |
| Kube State Metrics | `KubeStateMetrics` | Kubernetes object metrics exporter |
| OpenCost | `OpenCost` | Kubernetes cost monitoring |
| Dex Config Operator | `DexConfigOperator` | Dynamic Dex connector and OAuth client management |
| FinOps Operator | `FinOpsOperator` | MTO-specific cost management platform |

All CRs use the API group `dependencies.tenantoperator.stakater.com/v1alpha1`.

## How It Works

Each Custom Resource maps to an embedded Helm chart. The CR's `.spec` is passed directly as chart values (enabled by `x-kubernetes-preserve-unknown-fields: true`), so any value supported by the upstream chart can be set in the CR spec. When you create or update a CR, the operator reconciles the corresponding Helm release to match the desired state.

```
   Create/Update CR          Operator reconciles           Helm release deployed
┌──────────────────┐    ┌──────────────────────────┐    ┌──────────────────────┐
│  kind: Dex       │───▶│  MTO Dependencies        │───▶│  Pods, Services,     │
│  spec:           │    │  Operator                 │    │  ConfigMaps, etc.    │
│    replicaCount: │    │  (watches CRs, manages    │    │                      │
│    config: ...   │    │   Helm releases)          │    │                      │
└──────────────────┘    └──────────────────────────┘    └──────────────────────┘
```

## Next Steps

- [CR Reference](cr-reference.md) — Field reference for all 7 Custom Resources
- Deployment guides — Step-by-step instructions for each component
