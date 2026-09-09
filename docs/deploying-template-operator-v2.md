# Deploying Template Operator v2

Template Operator v2 distributes templated Kubernetes resources across namespaces. Providers define `Template` CRs (Go templates or Helm charts); consumers instantiate them with `TemplateInstance` CRs. It ships a sync-enforcement webhook that can block tampering with rendered resources (`sync.mode: strict`).

Under MTO, the tenant-operator creates this CR automatically when `components.templateOperatorV2.mode: Managed` is set in the IntegrationConfig. Create the CR manually only for standalone use.

## Prerequisites

- MTO Dependencies Operator installed on the cluster
- A certificate source for the webhook serving cert:
  - **cert-manager** installed (the default, `certManager.enabled: true`), or
  - **OpenShift**: the service-ca operator, with the annotations shown below

## Minimal Example

```yaml
apiVersion: dependencies.tenantoperator.stakater.com/v1alpha1
kind: TemplateOperatorV2
metadata:
  name: template-operator-v2
  namespace: multi-tenant-operator
spec:
  controllerManager:
    replicas: 1
    manager:
      image:
        repository: ghcr.io/stakater/public/template-operator-v2
        tag: v0.0.8
  kubernetesClusterDomain: cluster.local
```

## Common Customizations

**OpenShift (no cert-manager) — use the service-ca operator:**

```yaml
spec:
  certManager:
    enabled: false
  webhookConfig:
    annotations:
      service.beta.openshift.io/inject-cabundle: "true"
  webhookService:
    annotations:
      service.beta.openshift.io/serving-cert-secret-name: template-operator-v2-webhook-server-cert
```

**Grant the operator access to the resource kinds your templates render:**

```yaml
spec:
  rbac:
    additionalRules:
      - apiGroups: [""]
        resources: [configmaps]
        verbs: ["*"]
```

> Security note: TemplateInstances resolve `valueFrom` parameters with the
> operator's own identity. Every read permission granted here is therefore
> effectively available to any user who can create a TemplateInstance.

**Rename the webhook serving-cert Secret** (the default is already unique per component):

```yaml
spec:
  webhook:
    certSecretName: my-webhook-cert
```

## Verification

```bash
kubectl get templateoperatorv2 -n multi-tenant-operator
kubectl get deploy template-operator-v2-controller-manager -n multi-tenant-operator
kubectl get crd templates.templates.v2.stakater.com templateinstances.templates.v2.stakater.com
```

With `sync.mode: strict` on a Template, an UPDATE or DELETE on a rendered resource must be denied by the `sync-enforcement.templates.v2.stakater.com` webhook.

Note for OpenShift users: the bare resource name `templateinstance` resolves to OpenShift's own `template.openshift.io` group. Use the fully qualified names shown above.

## Further Reading

This is a Stakater-managed component. Refer to the sample CR in `config/samples/dependencies_v1alpha1_templateoperatorv2.yaml` for the full default values.
