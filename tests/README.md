# MTO Dependencies Operator Integration Tests

This directory contains integration tests for the MTO Dependencies Operator. The tests are designed to validate that Custom Resources (CRs) properly create and manage their corresponding Kubernetes deployments.

## Overview

The test suite includes bash-based integration tests that:
1. Create Custom Resources (CRs) for various dependencies
2. Validate that the operator creates corresponding Kubernetes deployments
3. Check that deployments become ready and functional
4. Clean up resources after testing

## Test Structure

```
tests/
├── run_tests.sh           # Main test runner script
├── helpers/
│   └── common.sh          # Common test helper functions
├── integration/
│   ├── test_dex.sh                    # Dex CR test
│   ├── test_prometheus.sh             # Prometheus CR test
│   ├── test_finops_operator.sh        # FinOps Operator CR test
│   ├── test_kube_state_metrics.sh     # KubeStateMetrics CR test
│   ├── test_postgres.sh               # Postgres CR test
│   └── test_opencost.sh               # OpenCost CR test
└── fixtures/
    ├── dex-test.yaml                  # Test Dex CR manifest
    ├── prometheus-test.yaml           # Test Prometheus CR manifest
    ├── finops-operator-test.yaml      # Test FinOps Operator CR manifest
    ├── kube-state-metrics-test.yaml   # Test KubeStateMetrics CR manifest
    ├── postgres-test.yaml             # Test Postgres CR manifest
    └── opencost-test.yaml             # Test OpenCost CR manifest
```

## Available Tests

### 1. Dex Test (`test_dex.sh`)
- Creates a Dex Custom Resource
- Validates that a Dex deployment is created
- Checks that the deployment becomes ready
- Verifies associated service creation

### 2. Prometheus Test (`test_prometheus.sh`)
- Creates a Prometheus Custom Resource
- Validates that a Prometheus deployment is created
- Checks that the deployment becomes ready
- Verifies ConfigMap and Service creation

### 3. KubeStateMetrics Test (`test_kube_state_metrics.sh`)
- Creates a KubeStateMetrics Custom Resource
- Validates that a KubeStateMetrics deployment is created
- Checks that the deployment becomes ready
- Verifies RBAC resources and service creation
- Tests metrics endpoint functionality

### 4. Postgres Test (`test_postgres.sh`)
- Creates a Postgres Custom Resource
- Validates that a Postgres StatefulSet or Deployment is created
- Checks that the resource becomes ready
- Verifies secret creation for credentials
- Tests PostgreSQL connection functionality

### 5. OpenCost Test (`test_opencost.sh`)
- Creates an OpenCost Custom Resource
- Validates that an OpenCost deployment is created
- Checks that the deployment becomes ready
- Verifies service and configmap creation
- Tests OpenCost metrics and health endpoints

### 6. FinOps Operator Test (`test_finops_operator.sh`)
- Creates an FinOps Operator Custom Resource
- Validates that an FinOps Operator deployment is created
- Checks that the deployment becomes ready
- Verifies service and configmap creation
- Tests FinOps Operator metrics and health endpoints

## Prerequisites

Before running the tests, ensure you have:

1. **kubectl** installed and configured to connect to a Kubernetes cluster
2. **helm** installed (used by the operator)
3. **curl** installed (for endpoint testing)
4. A Kubernetes cluster with:
   - The MTO Dependencies Operator installed and running (optional for basic CR validation)
   - Sufficient permissions to create namespaces, deployments, services, etc.
   - At least 1GB of free memory for test workloads

## Running Tests

### Quick Start

```bash
# Run all tests
make test-integration

# Or directly
./tests/run_tests.sh
```

### Running Specific Tests

```bash
# Run individual tests
make test-dex
make test-prometheus
make test-kube-state-metrics
make test-postgres
make test-opencost
make test-finops-operator

# Or directly
./tests/run_tests.sh dex
./tests/run_tests.sh prometheus
./tests/run_tests.sh kube_state_metrics
./tests/run_tests.sh postgres
./tests/run_tests.sh opencost
./tests/run_tests.sh finops_operator
```

### Running Tests in Parallel

```bash
# Run all tests in parallel (faster but harder to debug)
make test-integration-parallel

# Or directly
./tests/run_tests.sh --parallel
```

### Test Options

The test runner supports various options:

```bash
# Custom namespace
./tests/run_tests.sh --namespace my-test-ns

# Custom timeout (default: 300 seconds)
./tests/run_tests.sh --timeout 600

# Don't cleanup on failure (for debugging)
./tests/run_tests.sh --no-cleanup-on-failure

# Dry run (show what would be executed)
./tests/run_tests.sh --dry-run

# List available tests
./tests/run_tests.sh --list

# Help
./tests/run_tests.sh --help
```

## Environment Variables

You can customize test behavior using environment variables:

```bash
# Test namespace (default: mto-test)
export TEST_NAMESPACE="my-test-namespace"

# Test timeout in seconds (default: 300)
export TEST_TIMEOUT=600

# Run tests in parallel (default: false)
export PARALLEL_TESTS=true

# Cleanup on failure (default: true)
export CLEANUP_ON_FAILURE=false

# Operator namespace (default: mto-dependencies-operator-system)
export OPERATOR_NAMESPACE="mto-operator-system"
```

## What the Tests Validate

### Basic Functionality
- Custom Resource creation and acceptance by the API server
- Deployment creation triggered by the operator
- Deployment readiness (all pods running and ready)
- Service creation and configuration

### Resource Properties
- Correct labels and metadata on created resources
- Proper resource requests and limits
- Correct image tags and configurations

### Cleanup
- Proper resource cleanup when CRs are deleted
- No resource leaks between test runs

## Test Output

Tests provide colored output with different log levels:
- **INFO** (Blue): General information
- **SUCCESS** (Green): Successful operations
- **WARNING** (Yellow): Non-critical issues
- **ERROR** (Red): Test failures

Example output:
```
[INFO] Starting Dex CR Test
[INFO] Prerequisites check passed
[INFO] Creating namespace mto-test-dex
[INFO] Applying Dex Custom Resource
[SUCCESS] dex/dex-test created
[INFO] Waiting for Dex deployment to be created
[SUCCESS] deployment/dex-test created
[INFO] Waiting for Dex deployment to be ready
[SUCCESS] Deployment dex-test is ready (1/1 replicas)
[SUCCESS] Dex CR Test completed successfully
```

## Troubleshooting

### Common Issues

1. **Prerequisites Check Failed**
   - Ensure kubectl and helm are installed and in PATH
   - Verify kubectl can connect to your cluster: `kubectl cluster-info`

2. **Timeout Waiting for Resources**
   - Check if the operator is running: `kubectl get pods -n mto-dependencies-operator-system`
   - Increase timeout: `./tests/run_tests.sh --timeout 600`
   - Check operator logs for errors

3. **Permission Denied**
   - Ensure your kubectl context has sufficient permissions
   - Check if you can create namespaces and deployments

4. **Deployment Not Created**
   - Verify the operator is installed and running
   - Check operator logs: `kubectl logs -n mto-dependencies-operator-system deployment/mto-dependencies-operator-controller-manager`
   - Validate CRDs are installed: `kubectl get crd | grep dependencies.tenantoperator.stakater.com`

### Debugging Failed Tests

When tests fail, they provide debug information including:
- Resource status descriptions
- Pod logs (if available)
- Current state of resources in the test namespace

For additional debugging, use the `--no-cleanup-on-failure` flag to preserve resources for manual inspection:

```bash
./tests/run_tests.sh --no-cleanup-on-failure dex
kubectl get all -n mto-test-dex
kubectl describe dex dex-test -n mto-test-dex
```

### Clean Up Stuck Resources

If tests leave resources behind:

```bash
# Delete test namespaces
kubectl delete namespace mto-test-dex mto-test-prometheus mto-test-kube_state_metrics --ignore-not-found=true

# Delete cluster-level resources (if any)
kubectl delete clusterrole kube-state-metrics-test --ignore-not-found=true
kubectl delete clusterrolebinding kube-state-metrics-test --ignore-not-found=true
```

## Extending the Tests

### Adding New Tests

1. Create a new CR fixture in `tests/fixtures/`
2. Create a new test script in `tests/integration/`
3. Add the test to the `AVAILABLE_TESTS` array in `run_tests.sh`
4. Add a Makefile target for the new test

### Test Script Template

```bash
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../helpers/common.sh"

TEST_NAME="My New Test"
CR_NAME="my-resource-test"
DEPLOYMENT_NAME="my-resource-test"

test_my_resource_cr() {
    local start_time
    start_time=$(date +%s)
    
    log_info "Starting $TEST_NAME"
    
    # Check prerequisites
    if ! check_prerequisites; then
        return 1
    fi
    
    # Create test namespace
    create_test_namespace
    
    # Apply CR and wait for deployment
    if ! apply_and_wait "$SCRIPT_DIR/../fixtures/my-resource-test.yaml" "myresource" "$CR_NAME"; then
        return 1
    fi
    
    if ! wait_for_resource "deployment" "$DEPLOYMENT_NAME"; then
        return 1
    fi
    
    if ! wait_for_deployment_ready "$DEPLOYMENT_NAME"; then
        return 1
    fi
    
    # Additional validations...
    
    local end_time
    end_time=$(date +%s)
    
    log_success "$TEST_NAME completed successfully"
    print_test_summary "$TEST_NAME" "$start_time" "$end_time" "PASSED"
    
    return 0
}

cleanup_my_resource_test() {
    delete_cr_and_wait "myresource" "$CR_NAME" || true
    cleanup_test_namespace || true
}

main() {
    trap cleanup_my_resource_test EXIT
    
    if ! test_my_resource_cr; then
        log_error "$TEST_NAME FAILED"
        return 1
    fi
    
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

## Contributing

When contributing new tests:
1. Follow the existing test structure and naming conventions
2. Include comprehensive error handling and debug output
3. Ensure tests clean up after themselves
4. Add appropriate documentation
5. Test both success and failure scenarios

## License

These tests are part of the MTO Dependencies Operator project and follow the same license terms.
