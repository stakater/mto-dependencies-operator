# MTO Dependencies Operator

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Go Report Card](https://goreportcard.com/badge/github.com/stakater-ab/mto-dependencies-operator)](https://goreportcard.com/report/github.com/stakater-ab/mto-dependencies-operator)

A Kubernetes operator that manages common infrastructure dependencies required by Multi-Tenant Operator (MTO) as Custom Resources using Helm charts.

## Overview

The MTO Dependencies Operator simplifies the deployment and management of essential infrastructure components needed by the Multi-Tenant Operator ecosystem. Instead of manually managing multiple Helm releases, this operator provides a declarative way to deploy and configure dependencies through Kubernetes Custom Resources.

### Supported Dependencies

| Component | Custom Resource | Description |
|-----------|----------------|-------------|
| **Dex** | `Dex` | OpenID Connect (OIDC) identity provider with pluggable connectors |
| **Prometheus** | `Prometheus` | Monitoring and alerting system with time series database |
| **Kube State Metrics** | `KubeStateMetrics` | Kubernetes object metrics exporter |
| **PostgreSQL** | `Postgres` | Production-ready PostgreSQL database with high availability |
| **OpenCost** | `OpenCost` | Kubernetes cost monitoring and management platform |
| **FinOps Operator** | `FinOps Operator` | MTO cost monitoring and management platform |

## Architecture

```
┌─────────────────┐    ┌───────────────────┐    ┌─────────────────┐
│   User/GitOps   │    │  MTO Dependencies │    │   Infrastructure│
│                 │    │     Operator      │    │   Components    │
│                 │────▶                   │────▶                 │
│ Custom Resource │    │  (Helm Operator)  │    │  Helm Releases  │
│  (Dex, etc.)    │    │                   │    │  (Pods, SVCs)   │
└─────────────────┘    └───────────────────┘    └─────────────────┘
```

The operator watches for Custom Resource changes and automatically:
1. Validates the configuration
2. Deploys the corresponding Helm chart
3. Manages the lifecycle of the infrastructure components
4. Handles upgrades and configuration changes

## Quick Start

### Prerequisites

- Kubernetes cluster (v1.14+)
- kubectl configured to access your cluster
- Operator Lifecycle Manager (OLM) installed (optional)

### Installation

#### Option 1: Using kubectl

```bash
# Install the operator
kubectl apply -f https://raw.githubusercontent.com/stakater-ab/mto-dependencies-operator/refs/heads/main/dist/install.yaml

# Verify installation
kubectl get pods -n mto-dependencies-operator-system
```

#### Option 2: From Source

```bash
# Clone the repository
git clone https://github.com/stakater-ab/mto-dependencies-operator.git
cd mto-dependencies-operator

# Deploy to your cluster
make deploy
```

### Basic Usage

Create a simple Dex identity provider:

```yaml
apiVersion: dependencies.tenantoperator.stakater.com/v1alpha1
kind: Dex
metadata:
  name: my-dex
  namespace: auth-system
spec:
  config:
    issuer: https://dex.example.com
    storage:
      type: kubernetes
      config:
        inCluster: true
    staticClients:
    - id: my-app
      name: 'My Application'
      redirectURIs:
      - 'https://my-app.example.com/callback'
      secret: my-secret-key
```

Apply the resource:

```bash
kubectl apply -f dex-example.yaml
```

The operator will automatically deploy and configure Dex using the embedded Helm chart.

## Custom Resources

### Dex (OpenID Connect Provider)

```yaml
apiVersion: dependencies.tenantoperator.stakater.com/v1alpha1
kind: Dex
metadata:
  name: dex-example
spec:
  config:
    issuer: https://dex.example.com
    storage:
      type: kubernetes
      config:
        inCluster: true
    connectors:
    - type: oidc
      id: keycloak
      name: Keycloak
      config:
        issuer: https://keycloak.example.com/realms/mto
        clientID: mto-console
        redirectURI: https://dex.example.com/callback
    staticClients:
    - id: my-app
      redirectURIs: ['https://my-app.example.com/callback']
      name: 'My App'
      secret: my-secret
```

### Prometheus (Monitoring Stack)

```yaml
apiVersion: dependencies.tenantoperator.stakater.com/v1alpha1
kind: Prometheus
metadata:
  name: prometheus-example
spec:
  server:
    retention: "15d"
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 200m
        memory: 256Mi
  alertmanager:
    enabled: true
  nodeExporter:
    enabled: true
  kubeStateMetrics:
    enabled: true
```

### PostgreSQL (Database)

```yaml
apiVersion: dependencies.tenantoperator.stakater.com/v1alpha1
kind: Postgres
metadata:
  name: postgres-example
spec:
  auth:
    postgresPassword: "secure-password"
    username: "myuser"
    password: "mypass"
    database: "mydb"
  primary:
    persistence:
      enabled: true
      size: 10Gi
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
```

### KubeStateMetrics

```yaml
apiVersion: dependencies.tenantoperator.stakater.com/v1alpha1
kind: KubeStateMetrics
metadata:
  name: kube-state-metrics-example
spec:
  replicas: 1
  resources:
    requests:
      cpu: 10m
      memory: 32Mi
  collectors:
    - deployments
    - pods
    - services
```

### OpenCost

```yaml
apiVersion: dependencies.tenantoperator.stakater.com/v1alpha1
kind: OpenCost
metadata:
  name: opencost-example
spec:
  opencost:
    exporter:
      defaultClusterId: "my-cluster"
    prometheus:
      external:
        enabled: true
        url: "http://prometheus-server.monitoring.svc.cluster.local"
```

### FinOps Operator

Use provided sample to deploy FinOps Operator:

```yaml
kubectl apply -f config/samples/dependencies_v1alpha1_finopsoperator.yaml
```

## Development

### Prerequisites

- Go 1.21+
- Docker
- kubectl
- kind (for local testing)
- Helm 3.x

### Local Development

```bash
# Clone the repository
git clone https://github.com/stakater-ab/mto-dependencies-operator.git
cd mto-dependencies-operator

# Install dependencies
make kind                    # Install kind locally
make cluster                 # Create local test cluster
make install                 # Install CRDs

# Run the operator locally
make run

# In another terminal, test with sample resources
kubectl apply -f examples/
```

#### Adding a new Helm Chart

1. Dowload the desired Helm chart and place it in the `helm-charts/` directory.
2. Create a new API type
```bash
  # make sure you have create a feature branch prior to running below commands.
  
  # downloads operator sdk and places it in ./bin/operator-sdk if not already present
  make operator-sdk 
  
  # Create a new API
  ./bin/operator-sdk create api \
    --plugins=helm \
    --group=dependencies \
    --version=v1alpha1 \
    --kind=<name-of-operator-kind> \
    --helm-chart=helm-charts/<name-of-helm-chart>
    
  # commit your changes.
```

### Testing

The operator includes comprehensive integration tests:

```bash
# Lint Helm charts
make lint

# Run all integration tests
make test

# Run specific tests
make test-dex
make test-prometheus
make test-postgres

# Run tests in parallel
make test-integration-parallel
```

### Building and Deployment

```bash
# Build Docker image
make docker-build IMG=your-registry/mto-dependencies-operator:latest

# Push image
make docker-push IMG=your-registry/mto-dependencies-operator:latest

# Deploy to cluster
make deploy IMG=your-registry/mto-dependencies-operator:latest
```

## Configuration

### Operator Configuration

The operator can be configured through environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `WATCH_NAMESPACE` | `""` | Namespace to watch (empty = all namespaces) |
| `LEADER_ELECTION_NAMESPACE` | `mto-dependencies-operator-system` | Namespace for leader election |
| `ANSIBLE_VERBOSITY` | `0` | Ansible verbosity level |

### Helm Chart Values

Each Custom Resource spec is passed directly to the underlying Helm chart. Refer to individual chart documentation:

- [Dex Helm Chart](https://github.com/dexidp/helm-charts/tree/master/charts/dex)
- [Prometheus Helm Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus)
- [PostgreSQL Helm Chart](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)
- [OpenCost Helm Chart](https://github.com/opencost/opencost-helm-chart)
- [FinOps Operator Helm Chart](https://github.com/stakater-ab/finops-operator)

## Monitoring and Observability

The operator exposes metrics and supports monitoring through:

- **Metrics**: Prometheus metrics on port 8443
- **Health Checks**: Liveness and readiness probes
- **Logging**: Structured logging with configurable verbosity

### Available Metrics

- `controller_runtime_reconcile_total`: Total reconciliations per Custom Resource
- `controller_runtime_reconcile_errors_total`: Failed reconciliations
- `workqueue_adds_total`: Items added to work queue
- `rest_client_requests_total`: Kubernetes API requests

## Troubleshooting

### Common Issues

1. **Custom Resource not reconciling**
   ```bash
   # Check operator logs
   kubectl logs -n mto-dependencies-operator-system deployment/mto-dependencies-operator-controller-manager
   
   # Check Custom Resource status
   kubectl describe dex my-dex-instance
   ```

2. **Helm chart deployment failing**
   ```bash
   # List Helm releases
   helm list -A
   
   # Check release status
   helm status my-dex-instance -n target-namespace
   ```

3. **Resource conflicts**
   ```bash
   # Check for existing resources
   kubectl get all -l app.kubernetes.io/managed-by=Helm
   ```

### Debug Mode

Enable debug logging:

```bash
kubectl patch deployment mto-dependencies-operator-controller-manager \
  -n mto-dependencies-operator-system \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/env/0/value", "value": "2"}]'
```

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Workflow

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run the test suite: `make test`
6. Submit a pull request

### Code Standards

- Follow Go best practices
- Add comprehensive tests
- Update documentation
- Use conventional commit messages

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/stakater-ab/mto-dependencies-operator/issues)
- **Discussions**: [GitHub Discussions](https://github.com/stakater-ab/mto-dependencies-operator/discussions)
- **Slack**: [Stakater Community](https://slack.stakater.com)

## Acknowledgments

- Built on the [Operator SDK](https://sdk.operatorframework.io/)
- Uses the [Helm Operator](https://sdk.operatorframework.io/docs/building-operators/helm/) approach
- Integrates community-maintained Helm charts for each dependency
