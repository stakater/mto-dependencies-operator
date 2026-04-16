# Deploying FinOps Operator

The FinOpsOperator is the MTO-specific cost management platform. It works alongside OpenCost to provide tenant-aware cost monitoring and a gateway for the MTO console.

## Prerequisites

- MTO Dependencies Operator installed on the cluster
- A running OpenCost instance (deployed via the OpenCost CR)
- A namespace for the FinOps Operator deployment

## Minimal Example

```yaml
apiVersion: dependencies.tenantoperator.stakater.com/v1alpha1
kind: FinOpsOperator
metadata:
  name: finops-operator
  namespace: finops-operator-system
spec:
  controllerManager:
    replicas: 1
    manager:
      image:
        repository: ghcr.io/stakater/public/finops-operator
        tag: v0.1.1
      env:
        opencostDeploymentName: opencost
        opencostDeploymentNamespace: opencost-system
  finopsGatewayGateway:
    replicas: 1
    finopsGatewayContainer:
      image:
        repository: ghcr.io/stakater/finops-gateway
        tag: v0.1.0
      env:
        enableAuth: "false"
        port: "8080"
  finopsGatewayService:
    ports:
      - name: http
        port: 8080
        targetPort: 8080
    type: ClusterIP
  kubernetesClusterDomain: cluster.local
```

## Common Customizations

**Point to a different OpenCost deployment:**

```yaml
spec:
  controllerManager:
    manager:
      env:
        opencostDeploymentName: my-opencost
        opencostDeploymentNamespace: monitoring
```

**Enable authentication on the gateway:**

```yaml
spec:
  finopsGatewayGateway:
    finopsGatewayContainer:
      env:
        enableAuth: "true"
        mtoGatewayUrl: https://mto-gateway.example.com
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
kubectl get pods -n finops-operator-system
kubectl get finopsoperator -n finops-operator-system
```

## Further Reading

This is a Stakater-managed component. Refer to the sample CR in `config/samples/dependencies_v1alpha1_finopsoperator.yaml` for the full default values.
