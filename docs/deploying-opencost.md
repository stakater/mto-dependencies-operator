# Deploying OpenCost

The OpenCost CR deploys a cost monitoring solution that provides real-time Kubernetes cost visibility. It requires a Prometheus instance as a data source.

## Prerequisites

- MTO Dependencies Operator installed on the cluster
- A running Prometheus instance (deployed via the Prometheus CR or externally)
- A namespace for the OpenCost deployment

## Minimal Example

Using an in-cluster Prometheus:

```yaml
apiVersion: dependencies.tenantoperator.stakater.com/v1alpha1
kind: OpenCost
metadata:
  name: opencost
  namespace: opencost-system
spec:
  opencost:
    exporter:
      defaultClusterId: my-cluster
    prometheus:
      internal:
        enabled: true
        serviceName: prometheus-server
        namespaceName: prometheus-system
        port: 80
    ui:
      enabled: true
```

## Common Customizations

**Use an external Prometheus:**

```yaml
spec:
  opencost:
    prometheus:
      internal:
        enabled: false
      external:
        enabled: true
        url: https://prometheus.example.com
```

**Enable custom pricing model:**

```yaml
spec:
  opencost:
    customPricing:
      enabled: true
      provider: custom
      costModel:
        CPU: 1.25
        RAM: 0.50
        storage: 0.25
        GPU: 0.95
```

**Disable the UI and set resource limits:**

```yaml
spec:
  opencost:
    ui:
      enabled: false
    exporter:
      resources:
        requests:
          cpu: 10m
          memory: 55Mi
        limits:
          memory: 1Gi
```

## Verification

```bash
kubectl get pods -n opencost-system -l app.kubernetes.io/name=opencost
kubectl get opencost -n opencost-system
```

## Further Reading

- [OpenCost Helm Chart](https://github.com/opencost/opencost-helm-chart)
- [OpenCost Documentation](https://www.opencost.io/docs/)
