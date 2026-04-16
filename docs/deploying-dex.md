# Deploying Dex

Dex is an OpenID Connect (OIDC) identity provider that supports pluggable upstream connectors (OIDC, LDAP, GitHub, etc.) and issues tokens to downstream client applications.

## Prerequisites

- MTO Dependencies Operator installed on the cluster
- A namespace for the Dex deployment
- (Optional) TLS certificates or an ingress controller if exposing Dex externally

## Minimal Example

```yaml
apiVersion: dependencies.tenantoperator.stakater.com/v1alpha1
kind: Dex
metadata:
  name: dex
  namespace: dex-system
spec:
  replicaCount: 1
  config:
    issuer: https://dex.example.com
    storage:
      type: kubernetes
      config:
        inCluster: true
    staticClients:
      - id: my-app
        name: My Application
        redirectURIs:
          - https://my-app.example.com/callback
        secret: my-client-secret
  rbac:
    create: true
    createClusterScoped: true
```

## Common Customizations

**Add an upstream OIDC connector:**

```yaml
spec:
  config:
    connectors:
      - type: oidc
        id: keycloak
        name: Keycloak
        config:
          issuer: https://keycloak.example.com/realms/mto
          clientID: mto-console
          clientSecret: my-secret
          redirectURI: https://dex.example.com/callback
```

**Enable ingress:**

```yaml
spec:
  ingress:
    enabled: true
    className: nginx
    hosts:
      - host: dex.example.com
        paths:
          - path: /
            pathType: ImplementationSpecific
    tls:
      - secretName: dex-tls
        hosts:
          - dex.example.com
```

**Set resource limits:**

```yaml
spec:
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 128Mi
```

## Verification

```bash
kubectl get pods -n dex-system -l app.kubernetes.io/name=dex
kubectl get dex -n dex-system
```

## Further Reading

- [Dex Helm Chart](https://github.com/dexidp/helm-charts)
- [Dex Documentation](https://dexidp.io/docs/)
