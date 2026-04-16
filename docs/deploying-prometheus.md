# Deploying Prometheus

The Prometheus CR deploys a full monitoring stack including the Prometheus server, Alertmanager, Node Exporter, Kube State Metrics, and Pushgateway.

## Prerequisites

- MTO Dependencies Operator installed on the cluster
- A namespace for the Prometheus deployment
- A StorageClass available in the cluster (or use the default)

## Minimal Example

```yaml
apiVersion: dependencies.tenantoperator.stakater.com/v1alpha1
kind: Prometheus
metadata:
  name: prometheus
  namespace: prometheus-system
spec:
  server:
    retention: "15d"
    persistentVolume:
      enabled: true
      size: 8Gi
  alertmanager:
    enabled: true
  prometheus-node-exporter:
    enabled: true
  kube-state-metrics:
    enabled: true
```

## Common Customizations

**Disable sub-components you don't need:**

```yaml
spec:
  alertmanager:
    enabled: false
  prometheus-pushgateway:
    enabled: false
  prometheus-node-exporter:
    enabled: false
  kube-state-metrics:
    enabled: false
```

**Set resource limits on the server:**

```yaml
spec:
  server:
    resources:
      requests:
        cpu: 200m
        memory: 512Mi
      limits:
        cpu: "1"
        memory: 2Gi
```

**Enable ingress for the Prometheus server:**

```yaml
spec:
  server:
    ingress:
      enabled: true
      ingressClassName: nginx
      hosts:
        - prometheus.example.com
      tls:
        - secretName: prometheus-tls
          hosts:
            - prometheus.example.com
```

## Verification

```bash
kubectl get pods -n prometheus-system -l app.kubernetes.io/name=prometheus
kubectl get prometheus -n prometheus-system
```

## Further Reading

- [Prometheus Community Helm Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus)
