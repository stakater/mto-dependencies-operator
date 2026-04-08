#!/bin/bash

# Test script for Dex Custom Resource
# This test creates a Dex CR and validates that the corresponding deployment is created

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../helpers/common.sh"

TEST_NAME="Dex CR Test"
CR_NAME="dex-test"
DEPLOYMENT_NAME="dex-test"  # This should match the helm chart naming convention

test_dex_cr() {
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
    
    # Apply the Dex CR
    log_info "Applying Dex Custom Resource"
    if ! apply_and_wait "$SCRIPT_DIR/../fixtures/dex-test.yaml" "dex" "$CR_NAME"; then
        log_error "Failed to create Dex CR"
        return 1
    fi
    
    # Wait for the deployment to be created by the operator
    log_info "Waiting for Dex deployment to be created"
    if ! wait_for_resource "deployment" "$DEPLOYMENT_NAME"; then
        log_error "Dex deployment was not created"
        
        # Debug information
        log_info "Checking for any deployments in namespace:"
        kubectl get deployments -n "$NAMESPACE" || true
        
        log_info "Checking Dex CR status:"
        kubectl describe dex "$CR_NAME" -n "$NAMESPACE" || true
        
        return 1
    fi
    
    # Validate deployment is ready
    log_info "Waiting for Dex deployment to be ready"
    if ! wait_for_deployment_ready "$DEPLOYMENT_NAME"; then
        log_error "Dex deployment did not become ready"
        
        # Debug information
        log_info "Deployment status:"
        kubectl describe deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" || true
        
        log_info "Pod status:"
        kubectl get pods -l app.kubernetes.io/name=dex -n "$NAMESPACE" || true
        
        return 1
    fi
    
    # Validate the deployment has expected properties
    log_info "Validating Dex deployment properties"
    if ! validate_resource "deployment" "$DEPLOYMENT_NAME" "app.kubernetes.io/name=dex"; then
        return 1
    fi
    
    # Check that service was created
    log_info "Checking for Dex service"
    if ! wait_for_resource "service" "$CR_NAME"; then
        log_warning "Dex service was not created (this might be expected depending on configuration)"
    else
        log_success "Dex service created successfully"
    fi
    
    # Check pod status
    log_info "Checking pod status"
    local pods
    pods=$(kubectl get pods -l app.kubernetes.io/name=dex -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    if [ -n "$pods" ]; then
        for pod in $pods; do
            local pod_status
            pod_status=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
            log_info "Pod $pod status: $pod_status"
        done
    else
        log_warning "No Dex pods found"
    fi
    
    local end_time
    end_time=$(date +%s)
    
    log_success "$TEST_NAME completed successfully"
    print_test_summary "$TEST_NAME" "$start_time" "$end_time" "PASSED"
    
    return 0
}

cleanup_dex_test() {
    log_info "Cleaning up Dex test resources"
    
    # Delete the CR (this should trigger cleanup of managed resources)
    delete_cr_and_wait "dex" "$CR_NAME" || true
    
    # Clean up the test namespace
    cleanup_test_namespace || true
}

# Main execution
main() {
    local test_result=0
    
    # Set trap for cleanup on exit
    trap cleanup_dex_test EXIT
    
    # Run the test
    if ! test_dex_cr; then
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