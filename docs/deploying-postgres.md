# Deploying PostgreSQL

The Postgres CR deploys a production-ready PostgreSQL instance using the Bitnami chart, with support for standalone and replication architectures.

## Prerequisites

- MTO Dependencies Operator installed on the cluster
- A namespace for the PostgreSQL deployment
- A StorageClass available in the cluster (or use the default)

## Minimal Example

```yaml
apiVersion: dependencies.tenantoperator.stakater.com/v1alpha1
kind: Postgres
metadata:
  name: postgres
  namespace: postgres-system
spec:
  architecture: standalone
  auth:
    postgresPassword: "change-me"
    username: "appuser"
    password: "change-me"
    database: "appdb"
  primary:
    persistence:
      enabled: true
      size: 8Gi
```

## Common Customizations

**Use an existing Secret for credentials:**

```yaml
spec:
  auth:
    existingSecret: my-postgres-secret
    secretKeys:
      adminPasswordKey: postgres-password
      userPasswordKey: password
```

**Enable replication with read replicas:**

```yaml
spec:
  architecture: replication
  readReplicas:
    replicaCount: 2
    persistence:
      enabled: true
      size: 8Gi
```

**Enable Prometheus metrics exporter:**

```yaml
spec:
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
```

## Verification

```bash
kubectl get pods -n postgres-system -l app.kubernetes.io/name=postgresql
kubectl get postgres -n postgres-system
```

## Further Reading

- [Bitnami PostgreSQL Chart](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)
