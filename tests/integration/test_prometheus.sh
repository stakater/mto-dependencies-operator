#!/bin/bash

# Test script for Prometheus Custom Resource
# This test creates a Prometheus CR and validates that the corresponding deployment is created

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../helpers/common.sh"

TEST_NAME="Prometheus CR Test"
CR_NAME="prometheus-test"
DEPLOYMENT_NAME="prometheus-test-server"  # Prometheus chart creates deployment with -server suffix

test_prometheus_cr() {
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
    
    # Apply the Prometheus CR
    log_info "Applying Prometheus Custom Resource"
    if ! apply_and_wait "$SCRIPT_DIR/../fixtures/prometheus-test.yaml" "prometheus" "$CR_NAME"; then
        log_error "Failed to create Prometheus CR"
        return 1
    fi
    
    # Wait for the deployment to be created by the operator
    log_info "Waiting for Prometheus deployment to be created"
    if ! wait_for_resource "deployment" "$DEPLOYMENT_NAME"; then
        log_error "Prometheus deployment was not created"
        
        # Debug information
        log_info "Checking for any deployments in namespace:"
        kubectl get deployments -n "$NAMESPACE" || true
        
        log_info "Checking for any statefulsets in namespace:"
        kubectl get statefulsets -n "$NAMESPACE" || true
        
        log_info "Checking Prometheus CR status:"
        kubectl describe prometheus "$CR_NAME" -n "$NAMESPACE" || true
        
        return 1
    fi
    
    # Validate deployment is ready
    log_info "Waiting for Prometheus deployment to be ready"
    if ! wait_for_deployment_ready "$DEPLOYMENT_NAME"; then
        log_error "Prometheus deployment did not become ready"
        
        # Debug information
        log_info "Deployment status:"
        kubectl describe deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" || true
        
        log_info "Pod status:"
        kubectl get pods -l app.kubernetes.io/name=prometheus -n "$NAMESPACE" || true
        
        log_info "Pod logs (if available):"
        local pods
        pods=$(kubectl get pods -l app.kubernetes.io/name=prometheus -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
        for pod in $pods; do
            if [ -n "$pod" ]; then
                log_info "Logs for pod $pod:"
                kubectl logs "$pod" -n "$NAMESPACE" --tail=20 || true
            fi
        done
        
        return 1
    fi
    
    # Validate the deployment has expected properties
    log_info "Validating Prometheus deployment properties"
    if ! validate_resource "deployment" "$DEPLOYMENT_NAME" "app.kubernetes.io/name=prometheus"; then
        return 1
    fi
    
    # Check that service was created
    log_info "Checking for Prometheus service"
    if ! wait_for_resource "service" "prometheus-test-server"; then
        log_warning "Prometheus service was not created (this might be expected depending on configuration)"
    else
        log_success "Prometheus service created successfully"
    fi
    
    # Check that configmap was created
    log_info "Checking for Prometheus configmap"
    if ! wait_for_resource "configmap" "prometheus-test-server"; then
        log_warning "Prometheus configmap was not created (this might be expected depending on configuration)"
    else
        log_success "Prometheus configmap created successfully"
    fi
    
    # Check pod status and basic functionality
    log_info "Checking pod status and basic functionality"
    local pods
    pods=$(kubectl get pods -l app.kubernetes.io/name=prometheus -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
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
            fi
        done
    else
        log_warning "No Prometheus pods found"
    fi
    
    local end_time
    end_time=$(date +%s)
    
    log_success "$TEST_NAME completed successfully"
    print_test_summary "$TEST_NAME" "$start_time" "$end_time" "PASSED"
    
    return 0
}

cleanup_prometheus_test() {
    log_info "Cleaning up Prometheus test resources"
    
    # Delete the CR (this should trigger cleanup of managed resources)
    delete_cr_and_wait "prometheus" "$CR_NAME" || true
    
    # Clean up the test namespace
    cleanup_test_namespace || true
}

# Main execution
main() {
    local test_result=0
    
    # Set trap for cleanup on exit
    trap cleanup_prometheus_test EXIT
    
    # Run the test
    if ! test_prometheus_cr; then
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