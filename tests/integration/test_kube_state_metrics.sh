#!/bin/bash

# Test script for KubeStateMetrics Custom Resource
# This test creates a KubeStateMetrics CR and validates that the corresponding deployment is created

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../helpers/common.sh"

TEST_NAME="KubeStateMetrics CR Test"
CR_NAME="kube-state-metrics-test"
DEPLOYMENT_NAME="kube-state-metrics-test"  # This should match the helm chart naming convention

test_kube_state_metrics_cr() {
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
    
    # Apply the KubeStateMetrics CR
    log_info "Applying KubeStateMetrics Custom Resource"
    if ! apply_and_wait "$SCRIPT_DIR/../fixtures/kube-state-metrics-test.yaml" "kubestatemetrics" "$CR_NAME"; then
        log_error "Failed to create KubeStateMetrics CR"
        return 1
    fi
    
    # Wait for the deployment to be created by the operator
    log_info "Waiting for KubeStateMetrics deployment to be created"
    if ! wait_for_resource "deployment" "$DEPLOYMENT_NAME"; then
        log_error "KubeStateMetrics deployment was not created"
        
        # Debug information
        log_info "Checking for any deployments in namespace:"
        kubectl get deployments -n "$NAMESPACE" || true
        
        log_info "Checking KubeStateMetrics CR status:"
        kubectl describe kubestatemetrics "$CR_NAME" -n "$NAMESPACE" || true
        
        return 1
    fi
    
    # Validate deployment is ready
    log_info "Waiting for KubeStateMetrics deployment to be ready"
    if ! wait_for_deployment_ready "$DEPLOYMENT_NAME"; then
        log_error "KubeStateMetrics deployment did not become ready"
        
        # Debug information
        log_info "Deployment status:"
        kubectl describe deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" || true
        
        log_info "Pod status:"
        kubectl get pods -l app.kubernetes.io/name=kube-state-metrics -n "$NAMESPACE" || true
        
        log_info "Pod logs (if available):"
        local pods
        pods=$(kubectl get pods -l app.kubernetes.io/name=kube-state-metrics -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
        for pod in $pods; do
            if [ -n "$pod" ]; then
                log_info "Logs for pod $pod:"
                kubectl logs "$pod" -n "$NAMESPACE" --tail=20 || true
            fi
        done
        
        return 1
    fi
    
    # Validate the deployment has expected properties
    log_info "Validating KubeStateMetrics deployment properties"
    if ! validate_resource "deployment" "$DEPLOYMENT_NAME" "app.kubernetes.io/name=kube-state-metrics"; then
        return 1
    fi
    
    # Check that service was created
    log_info "Checking for KubeStateMetrics service"
    if ! wait_for_resource "service" "$CR_NAME"; then
        log_warning "KubeStateMetrics service was not created (this might be expected depending on configuration)"
    else
        log_success "KubeStateMetrics service created successfully"
    fi
    
    # Check that RBAC resources were created (if enabled)
    log_info "Checking for RBAC resources"
    if kubectl get serviceaccount "$CR_NAME" -n "$NAMESPACE" &> /dev/null; then
        log_success "ServiceAccount created successfully"
    else
        log_warning "ServiceAccount not found (this might be expected depending on configuration)"
    fi
    
    if kubectl get clusterrole "$CR_NAME" &> /dev/null; then
        log_success "ClusterRole created successfully"
    else
        log_warning "ClusterRole not found (this might be expected depending on configuration)"
    fi
    
    if kubectl get clusterrolebinding "$CR_NAME" &> /dev/null; then
        log_success "ClusterRoleBinding created successfully"
    else
        log_warning "ClusterRoleBinding not found (this might be expected depending on configuration)"
    fi
    
    # Check pod status and basic functionality
    log_info "Checking pod status and basic functionality"
    local pods
    pods=$(kubectl get pods -l app.kubernetes.io/name=kube-state-metrics -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
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
                
                # Test metrics endpoint if pod is ready
                if [ "$ready" = "True" ]; then
                    log_info "Testing metrics endpoint on pod $pod"
                    # Use kubectl port-forward to test the metrics endpoint
                    timeout 10 kubectl port-forward pod/"$pod" 8080:8080 -n "$NAMESPACE" &
                    local pf_pid=$!
                    sleep 3
                    
                    if curl -s http://localhost:8080/metrics | head -5 > /dev/null 2>&1; then
                        log_success "Metrics endpoint is responding"
                    else
                        log_warning "Metrics endpoint test failed or timed out"
                    fi
                    
                    # Clean up port-forward
                    kill $pf_pid 2>/dev/null || true
                fi
            fi
        done
    else
        log_warning "No KubeStateMetrics pods found"
    fi
    
    local end_time
    end_time=$(date +%s)
    
    log_success "$TEST_NAME completed successfully"
    print_test_summary "$TEST_NAME" "$start_time" "$end_time" "PASSED"
    
    return 0
}

cleanup_kube_state_metrics_test() {
    log_info "Cleaning up KubeStateMetrics test resources"
    
    # Delete the CR (this should trigger cleanup of managed resources)
    delete_cr_and_wait "kubestatemetrics" "$CR_NAME" || true
    
    # Clean up any cluster-level resources that might have been created
    kubectl delete clusterrole "$CR_NAME" --ignore-not-found=true || true
    kubectl delete clusterrolebinding "$CR_NAME" --ignore-not-found=true || true
    
    # Clean up the test namespace
    cleanup_test_namespace || true
}

# Main execution
main() {
    local test_result=0
    
    # Set trap for cleanup on exit
    trap cleanup_kube_state_metrics_test EXIT
    
    # Run the test
    if ! test_kube_state_metrics_cr; then
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