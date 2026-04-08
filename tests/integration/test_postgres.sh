#!/bin/bash

# Test script for Postgres Custom Resource
# This test creates a Postgres CR and validates that the corresponding deployment/statefulset is created

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../helpers/common.sh"

TEST_NAME="Postgres CR Test"
CR_NAME="postgres-test"
STATEFULSET_NAME="postgres-test-postgresql"  # PostgreSQL chart creates StatefulSet with -postgresql suffix
DEPLOYMENT_NAME="postgres-test-postgresql"   # Fallback to deployment if used

test_postgres_cr() {
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
    
    # Apply the Postgres CR
    log_info "Applying Postgres Custom Resource"
    if ! apply_and_wait "$SCRIPT_DIR/../fixtures/postgres-test.yaml" "postgres" "$CR_NAME"; then
        log_error "Failed to create Postgres CR"
        return 1
    fi
    
    # PostgreSQL can be deployed as either StatefulSet or Deployment, try both
    local postgres_resource_type=""
    local postgres_resource_name=""
    
    # Check for StatefulSet first (more common for PostgreSQL)
    log_info "Checking for Postgres StatefulSet"
    if wait_for_resource "statefulset" "$STATEFULSET_NAME" 2>/dev/null; then
        postgres_resource_type="statefulset"
        postgres_resource_name="$STATEFULSET_NAME"
        log_info "Found Postgres StatefulSet"
    else
        # Fall back to checking for Deployment
        log_info "StatefulSet not found, checking for Postgres Deployment"
        if wait_for_resource "deployment" "$DEPLOYMENT_NAME"; then
            postgres_resource_type="deployment"
            postgres_resource_name="$DEPLOYMENT_NAME"
            log_info "Found Postgres Deployment"
        else
            log_error "Neither StatefulSet nor Deployment was created for Postgres"
            
            # Debug information
            log_info "Checking for any statefulsets in namespace:"
            kubectl get statefulsets -n "$NAMESPACE" || true
            
            log_info "Checking for any deployments in namespace:"
            kubectl get deployments -n "$NAMESPACE" || true
            
            log_info "Checking Postgres CR status:"
            kubectl describe postgres "$CR_NAME" -n "$NAMESPACE" || true
            
            return 1
        fi
    fi
    
    # Wait for the resource to be ready
    if [ "$postgres_resource_type" = "statefulset" ]; then
        log_info "Waiting for Postgres StatefulSet to be ready"
        if ! wait_for_statefulset_ready "$postgres_resource_name"; then
            log_error "Postgres StatefulSet did not become ready"
            
            # Debug information
            log_info "StatefulSet status:"
            kubectl describe statefulset "$postgres_resource_name" -n "$NAMESPACE" || true
            
            log_info "Pod status:"
            kubectl get pods -l app.kubernetes.io/name=postgresql -n "$NAMESPACE" || true
            
            log_info "Pod logs (if available):"
            local pods
            pods=$(kubectl get pods -l app.kubernetes.io/name=postgresql -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
            for pod in $pods; do
                if [ -n "$pod" ]; then
                    log_info "Logs for pod $pod:"
                    kubectl logs "$pod" -n "$NAMESPACE" --tail=20 || true
                fi
            done
            
            return 1
        fi
    else
        log_info "Waiting for Postgres Deployment to be ready"
        if ! wait_for_deployment_ready "$postgres_resource_name"; then
            log_error "Postgres Deployment did not become ready"
            
            # Debug information
            log_info "Deployment status:"
            kubectl describe deployment "$postgres_resource_name" -n "$NAMESPACE" || true
            
            log_info "Pod status:"
            kubectl get pods -l app.kubernetes.io/name=postgresql -n "$NAMESPACE" || true
            
            return 1
        fi
    fi
    
    # Validate the resource has expected properties
    log_info "Validating Postgres $postgres_resource_type properties"
    if ! validate_resource "$postgres_resource_type" "$postgres_resource_name" "app.kubernetes.io/name=postgresql"; then
        return 1
    fi
    
    # Check that service was created
    log_info "Checking for Postgres service"
    if ! wait_for_resource "service" "postgres-test-postgresql"; then
        log_warning "Postgres service was not created (this might be expected depending on configuration)"
    else
        log_success "Postgres service created successfully"
    fi
    
    # Check that secrets were created (PostgreSQL typically creates password secrets)
    log_info "Checking for Postgres secrets"
    local secrets
    secrets=$(kubectl get secrets -n "$NAMESPACE" -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$secrets" ]; then
        log_success "Postgres secrets created: $secrets"
    else
        log_warning "No Postgres secrets found (this might be expected depending on configuration)"
    fi
    
    # Check pod status and basic functionality
    log_info "Checking pod status and basic functionality"
    local pods
    pods=$(kubectl get pods -l app.kubernetes.io/name=postgresql -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
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
                
                # Test PostgreSQL connection if pod is ready
                if [ "$ready" = "True" ]; then
                    log_info "Testing PostgreSQL connection on pod $pod"
                    # Test if PostgreSQL is accepting connections
                    if kubectl exec "$pod" -n "$NAMESPACE" -- pg_isready -U postgres >/dev/null 2>&1; then
                        log_success "PostgreSQL is accepting connections"
                    else
                        log_warning "PostgreSQL connection test failed"
                    fi
                fi
            fi
        done
    else
        log_warning "No Postgres pods found"
    fi
    
    local end_time
    end_time=$(date +%s)
    
    log_success "$TEST_NAME completed successfully"
    print_test_summary "$TEST_NAME" "$start_time" "$end_time" "PASSED"
    
    return 0
}

cleanup_postgres_test() {
    log_info "Cleaning up Postgres test resources"
    
    # Delete the CR (this should trigger cleanup of managed resources)
    delete_cr_and_wait "postgres" "$CR_NAME" || true
    
    # Clean up the test namespace
    cleanup_test_namespace || true
}

# Main execution
main() {
    local test_result=0
    
    # Set trap for cleanup on exit
    trap cleanup_postgres_test EXIT
    
    # Run the test
    if ! test_postgres_cr; then
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