#!/bin/bash

# Test script for OpenCost Custom Resource
# This test creates an OpenCost CR using collector data source and validates the deployment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../helpers/common.sh"

TEST_NAME="OpenCost CR Test"
CR_NAME="opencost-test"
DEPLOYMENT_NAME="opencost-test"  # This should match the helm chart naming convention

test_opencost_cr() {
    local start_time
    start_time=$(date +%s)
    
    log_info "Starting $TEST_NAME"
    
    # Check prerequisites
    if ! check_prerequisites; then
        return 1
    fi
    
    # Check if operator is running (optional)
    check_operator_running
    
    # Create test namespace
    create_test_namespace

    helm install prometheus --repo https://prometheus-community.github.io/helm-charts prometheus \
  --namespace prometheus-system --create-namespace \
  --set prometheus-pushgateway.enabled=false \
  --set alertmanager.enabled=false \
  -f https://raw.githubusercontent.com/opencost/opencost/develop/kubernetes/prometheus/extraScrapeConfigs.yaml
    
    # Apply the OpenCost CR (using collector data source, no Prometheus dependency)
    log_info "Applying OpenCost Custom Resource"
    if ! apply_and_wait "$SCRIPT_DIR/../fixtures/opencost-test.yaml" "opencost" "$CR_NAME"; then
        log_error "Failed to create OpenCost CR"
        return 1
    fi
    
    # Wait for the deployment to be created by the operator
    log_info "Waiting for OpenCost deployment to be created"
    if ! wait_for_resource "deployment" "$DEPLOYMENT_NAME"; then
        log_error "OpenCost deployment was not created"
        
        # Debug information
        log_info "Checking for any deployments in namespace:"
        kubectl get deployments -n "$NAMESPACE" || true
        
        log_info "Checking OpenCost CR status:"
        kubectl describe opencost "$CR_NAME" -n "$NAMESPACE" || true
        
        return 1
    fi
    
    # Validate deployment is ready
    log_info "Waiting for OpenCost deployment to be ready"
    if ! wait_for_deployment_ready "$DEPLOYMENT_NAME"; then
        log_error "OpenCost deployment did not become ready"
        
        # Debug information
        log_info "Deployment status:"
        kubectl describe deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" || true
        
        log_info "Pod status:"
        kubectl get pods -l app.kubernetes.io/name=opencost -n "$NAMESPACE" || true
        
        log_info "Pod logs (if available):"
        local pods
        pods=$(kubectl get pods -l app.kubernetes.io/name=opencost -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
        for pod in $pods; do
            if [ -n "$pod" ]; then
                log_info "Logs for pod $pod:"
                kubectl logs "$pod" -n "$NAMESPACE" --tail=20 || true
            fi
        done
        
        return 1
    fi
    
    # Validate the deployment has expected properties
    log_info "Validating OpenCost deployment properties"
    if ! validate_resource "deployment" "$DEPLOYMENT_NAME" "app.kubernetes.io/name=opencost"; then
        return 1
    fi
    
    # Check that service was created
    log_info "Checking for OpenCost service"
    if ! wait_for_resource "service" "$CR_NAME"; then
        log_warning "OpenCost service was not created (this might be expected depending on configuration)"
    else
        log_success "OpenCost service created successfully"
    fi
    
    # Check that configmap was created (OpenCost often uses ConfigMaps for configuration)
    log_info "Checking for OpenCost configmap"
    local configmaps
    configmaps=$(kubectl get configmaps -n "$NAMESPACE" -l app.kubernetes.io/name=opencost -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$configmaps" ]; then
        log_success "OpenCost configmaps created: $configmaps"
    else
        log_warning "No OpenCost configmaps found (this might be expected depending on configuration)"
    fi
    
    # Check pod status and basic functionality
    log_info "Checking pod status and basic functionality"
    local pods
    pods=$(kubectl get pods -l app.kubernetes.io/name=opencost -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    if [ -n "$pods" ]; then
        for pod in $pods; do
            local pod_status
            pod_status=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
            log_info "Pod $pod status: $pod_status"
            
            # Check if pod is running and ready
            if [ "$pod_status" = "Running" ]; then
                local ready
                ready=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
                log_info "Pod $pod ready: $ready"
                
                # Test OpenCost endpoints if pod is ready
                if [ "$ready" = "True" ]; then
                    log_info "Testing OpenCost endpoints on pod $pod"
                    
                    # Test metrics endpoint (typically on port 9003)
                    timeout 10 kubectl port-forward pod/"$pod" 9003:9003 -n "$NAMESPACE" &
                    local pf_pid=$!
                    sleep 3
                    
                    # Test metrics endpoint
                    if curl -s http://localhost:9003/metrics | head -5 > /dev/null 2>&1; then
                        log_success "OpenCost metrics endpoint is responding"
                    else
                        log_warning "OpenCost metrics endpoint test failed or timed out"
                    fi
                    
                    # Test healthz endpoint if available
                    if curl -s http://localhost:9003/healthz > /dev/null 2>&1; then
                        log_success "OpenCost health endpoint is responding"
                    else
                        log_warning "OpenCost health endpoint test failed (this might be expected)"
                    fi
                    
                    # Clean up port-forward
                    kill $pf_pid 2>/dev/null || true
                fi
            fi
        done
    else
        log_warning "No OpenCost pods found"
    fi
    
    # Check for ServiceMonitor if enabled
    log_info "Checking for ServiceMonitor resources"
    if kubectl get servicemonitor "$CR_NAME" -n "$NAMESPACE" &> /dev/null; then
        log_success "ServiceMonitor created successfully"
    else
        log_warning "ServiceMonitor not found (this might be expected if monitoring is disabled)"
    fi
    
    local end_time
    end_time=$(date +%s)
    
    log_success "$TEST_NAME completed successfully"
    print_test_summary "$TEST_NAME" "$start_time" "$end_time" "PASSED"
    
    return 0
}

cleanup_opencost_test() {
    helm uninstall prometheus -n prometheus-system || true

    log_info "Cleaning up OpenCost test resources"
    
    # Delete the OpenCost CR first (this should trigger cleanup of managed resources)
    delete_cr_and_wait "opencost" "$CR_NAME" || true
    
    # Delete the Prometheus CR 
    delete_cr_and_wait "prometheus" "$PROMETHEUS_CR_NAME" || true
    
    # Clean up the test namespace
    cleanup_test_namespace || true
}

# Main execution
main() {
    local test_result=0
    
    # Set trap for cleanup on exit
    trap cleanup_opencost_test EXIT
    
    # Run the test
    if ! test_opencost_cr; then
        test_result=1
        log_error "$TEST_NAME FAILED"
    else
        log_success "$TEST_NAME PASSED"
    fi
    
    return $test_result
}

# Run the test if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi