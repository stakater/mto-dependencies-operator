# Deploying DexConfigOperator

The DexConfigOperator dynamically manages Dex connector and OAuth client configurations. It watches for custom resources that describe connectors and clients, and syncs them into a running Dex instance.

## Prerequisites

- MTO Dependencies Operator installed on the cluster
- A running Dex instance (deployed via the Dex CR or externally)
- A namespace for the DexConfigOperator deployment

## Minimal Example

```yaml
apiVersion: dependencies.tenantoperator.stakater.com/v1alpha1
kind: DexConfigOperator
metadata:
  name: dex-config-operator
  namespace: dex-system
spec:
  controllerManager:
    replicas: 1
    manager:
      image:
        repository: ghcr.io/stakater/public/dex-config-operator
        tag: v0.0.5
      env:
        dexNamespace: dex-system
      resources:
        limits:
          cpu: 500m
          memory: 128Mi
        requests:
          cpu: 10m
          memory: 64Mi
  kubernetesClusterDomain: cluster.local
```

## Common Customizations

**Point to a different Dex namespace:**

```yaml
spec:
  controllerManager:
    manager:
      env:
        dexNamespace: auth-system
```

**Adjust resource limits:**

```yaml
spec:
  controllerManager:
    manager:
      resources:
        limits:
          cpu: "1"
          memory: 256Mi
        requests:
          cpu: 50m
          memory: 64Mi
```

## Verification

```bash
kubectl get pods -n dex-system -l app.kubernetes.io/name=dex-config-operator
kubectl get dexconfigoperator -n dex-system
```

## Further Reading

This is a Stakater-managed component. Refer to the sample CR in `config/samples/dependencies_v1alpha1_dexconfigoperator.yaml` for the full default values.
