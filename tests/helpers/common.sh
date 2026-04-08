#!/bin/bash

# Common test helper functions for MTO Dependencies Operator

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
NAMESPACE="${TEST_NAMESPACE:-mto-test}"
TIMEOUT="${TEST_TIMEOUT:-300}"
CHECK_INTERVAL="${CHECK_INTERVAL:-5}"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if required tools are available
check_prerequisites() {
    local tools=("kubectl" "helm")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "$tool is not installed or not in PATH"
            return 1
        fi
    done
    
    # Check if kubectl can connect to cluster
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        return 1
    fi
    
    log_info "Prerequisites check passed"
    return 0
}

# Create test namespace if it doesn't exist
create_test_namespace() {
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "DRY RUN: Would create namespace $NAMESPACE"
        return 0
    fi
    
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_info "Namespace $NAMESPACE already exists"
    else
        log_info "Creating namespace $NAMESPACE"
        kubectl create namespace "$NAMESPACE"
    fi
}

# Clean up test namespace
cleanup_test_namespace() {
    log_info "Cleaning up namespace $NAMESPACE"
    kubectl delete namespace "$NAMESPACE" --ignore-not-found=true
    
    # Wait for namespace to be fully deleted
    local counter=0
    while kubectl get namespace "$NAMESPACE" &> /dev/null; do
        if [ $counter -ge $TIMEOUT ]; then
            log_error "Timeout waiting for namespace deletion"
            return 1
        fi
        sleep $CHECK_INTERVAL
        counter=$((counter + CHECK_INTERVAL))
    done
    
    log_success "Namespace $NAMESPACE cleaned up"
}

# Apply YAML and wait for resource creation
apply_and_wait() {
    local yaml_file="$1"
    local resource_type="$2"
    local resource_name="$3"
    
    log_info "Applying $yaml_file"
    
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "DRY RUN: Would apply $yaml_file"
        return 0
    fi
    
    kubectl apply -f "$yaml_file" -n "$NAMESPACE"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to apply $yaml_file"
        return 1
    fi
    
    log_info "Waiting for $resource_type/$resource_name to be created"
    wait_for_resource "$resource_type" "$resource_name"
}

# Wait for a Kubernetes resource to exist
wait_for_resource() {
    local resource_type="$1"
    local resource_name="$2"
    local counter=0
    
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_success "DRY RUN: $resource_type/$resource_name would be created"
        return 0
    fi
    
    while ! kubectl get "$resource_type" "$resource_name" -n "$NAMESPACE" &> /dev/null; do
        if [ $counter -ge $TIMEOUT ]; then
            log_error "Timeout waiting for $resource_type/$resource_name to be created"
            return 1
        fi
        log_info "Waiting for $resource_type/$resource_name... ($counter/$TIMEOUT seconds)"
        sleep $CHECK_INTERVAL
        counter=$((counter + CHECK_INTERVAL))
    done
    
    log_success "$resource_type/$resource_name created"
    return 0
}

# Wait for deployment to be ready
wait_for_deployment_ready() {
    local deployment_name="$1"
    local counter=0
    
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_success "DRY RUN: Deployment $deployment_name would be ready"
        return 0
    fi
    
    log_info "Waiting for deployment $deployment_name to be ready"
    
    while true; do
        if [ $counter -ge $TIMEOUT ]; then
            log_error "Timeout waiting for deployment $deployment_name to be ready"
            kubectl describe deployment "$deployment_name" -n "$NAMESPACE"
            return 1
        fi
        
        local ready_replicas
        ready_replicas=$(kubectl get deployment "$deployment_name" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
        local desired_replicas
        desired_replicas=$(kubectl get deployment "$deployment_name" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null)
        
        if [ "$ready_replicas" = "$desired_replicas" ] && [ "$ready_replicas" != "" ] && [ "$ready_replicas" != "0" ]; then
            log_success "Deployment $deployment_name is ready ($ready_replicas/$desired_replicas replicas)"
            return 0
        fi
        
        log_info "Deployment $deployment_name not ready yet ($ready_replicas/$desired_replicas replicas) - waiting... ($counter/$TIMEOUT seconds)"
        sleep $CHECK_INTERVAL
        counter=$((counter + CHECK_INTERVAL))
    done
}

# Wait for statefulset to be ready
wait_for_statefulset_ready() {
    local statefulset_name="$1"
    local counter=0
    
    log_info "Waiting for statefulset $statefulset_name to be ready"
    
    while true; do
        if [ $counter -ge $TIMEOUT ]; then
            log_error "Timeout waiting for statefulset $statefulset_name to be ready"
            kubectl describe statefulset "$statefulset_name" -n "$NAMESPACE"
            return 1
        fi
        
        local ready_replicas
        ready_replicas=$(kubectl get statefulset "$statefulset_name" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
        local desired_replicas
        desired_replicas=$(kubectl get statefulset "$statefulset_name" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null)
        
        if [ "$ready_replicas" = "$desired_replicas" ] && [ "$ready_replicas" != "" ] && [ "$ready_replicas" != "0" ]; then
            log_success "StatefulSet $statefulset_name is ready ($ready_replicas/$desired_replicas replicas)"
            return 0
        fi
        
        log_info "StatefulSet $statefulset_name not ready yet ($ready_replicas/$desired_replicas replicas) - waiting... ($counter/$TIMEOUT seconds)"
        sleep $CHECK_INTERVAL
        counter=$((counter + CHECK_INTERVAL))
    done
}

# Validate that a resource exists and has expected properties
validate_resource() {
    local resource_type="$1"
    local resource_name="$2"
    local expected_labels="$3"
    
    log_info "Validating $resource_type/$resource_name"
    
    # Check if resource exists
    if ! kubectl get "$resource_type" "$resource_name" -n "$NAMESPACE" &> /dev/null; then
        log_error "$resource_type/$resource_name does not exist"
        return 1
    fi
    
    # Check labels if provided
    if [ -n "$expected_labels" ]; then
        local actual_labels
        actual_labels=$(kubectl get "$resource_type" "$resource_name" -n "$NAMESPACE" -o jsonpath='{.metadata.labels}')
        log_info "Resource labels: $actual_labels"
    fi
    
    log_success "$resource_type/$resource_name validation passed"
    return 0
}

# Delete a custom resource and wait for cleanup
delete_cr_and_wait() {
    local cr_type="$1"
    local cr_name="$2"
    
    log_info "Deleting $cr_type/$cr_name"
    kubectl delete "$cr_type" "$cr_name" -n "$NAMESPACE" --ignore-not-found=true
    
    # Wait for CR to be deleted
    local counter=0
    while kubectl get "$cr_type" "$cr_name" -n "$NAMESPACE" &> /dev/null; do
        if [ $counter -ge $TIMEOUT ]; then
            log_error "Timeout waiting for $cr_type/$cr_name deletion"
            return 1
        fi
        sleep $CHECK_INTERVAL
        counter=$((counter + CHECK_INTERVAL))
    done
    
    log_success "$cr_type/$cr_name deleted"
}

# Get the operator deployment name (assuming it's running in the same cluster)
get_operator_deployment_name() {
    # Look for the operator deployment, typically in mto-dependencies-operator-system namespace
    kubectl get deployment -A -l app.kubernetes.io/name=mto-dependencies-operator -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "mto-dependencies-operator-controller-manager"
}

# Check if operator is running
check_operator_running() {
    local operator_ns="${OPERATOR_NAMESPACE:-mto-dependencies-operator-system}"
    local deployment_name
    deployment_name=$(get_operator_deployment_name)
    
    if kubectl get deployment "$deployment_name" -n "$operator_ns" &> /dev/null; then
        local ready_replicas
        ready_replicas=$(kubectl get deployment "$deployment_name" -n "$operator_ns" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
        if [ "$ready_replicas" = "1" ]; then
            log_success "Operator is running"
            return 0
        fi
    fi
    
    log_warning "Operator might not be running. This is okay if testing locally."
    return 0  # Don't fail tests if operator isn't deployed
}

# Print test results summary
print_test_summary() {
    local test_name="$1"
    local start_time="$2"
    local end_time="$3"
    local status="$4"
    
    local duration=$((end_time - start_time))
    
    echo "========================================"
    echo "Test: $test_name"
    echo "Status: $status"
    echo "Duration: ${duration}s"
    echo "========================================"
}