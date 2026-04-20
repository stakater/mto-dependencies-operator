# Deploying Kube State Metrics

The KubeStateMetrics CR deploys a standalone Kube State Metrics instance that exports Kubernetes object metrics for Prometheus. Use this when you need KSM independently of the Prometheus CR's bundled sub-chart.

## Prerequisites

- MTO Dependencies Operator installed on the cluster
- A namespace for the deployment

## Minimal Example

```yaml
apiVersion: dependencies.tenantoperator.stakater.com/v1alpha1
kind: KubeStateMetrics
metadata:
  name: kube-state-metrics
  namespace: monitoring
spec:
  replicas: 1
  rbac:
    create: true
    useClusterRole: true
```

By default, all 28 resource collectors are enabled (pods, deployments, services, nodes, etc.).

## Common Customizations

**Limit which resource types are collected:**

```yaml
spec:
  collectors:
    - deployments
    - pods
    - services
    - nodes
    - statefulsets
    - namespaces
```

**Enable a ServiceMonitor for Prometheus Operator:**

```yaml
spec:
  prometheus:
    monitor:
      enabled: true
      additionalLabels:
        release: prometheus
```

**Set resource limits:**

```yaml
spec:
  resources:
    requests:
      cpu: 10m
      memory: 32Mi
    limits:
      cpu: 100m
      memory: 128Mi
```

## Verification

```bash
kubectl get pods -n monitoring -l app.kubernetes.io/name=kube-state-metrics
kubectl get kubestatemetrics -n monitoring
```

## Further Reading

- [Kube State Metrics Helm Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-state-metrics)
