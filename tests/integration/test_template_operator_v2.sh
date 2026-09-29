#!/bin/bash

# Test script for TemplateOperatorV2 Custom Resource
# Creates a TemplateOperatorV2 CR and validates that the template-operator-v2
# deployment comes up and its CRDs are installed.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../helpers/common.sh"

TEST_NAME="TemplateOperatorV2 CR Test"
CR_NAME="templateoperatorv2-test"
DEPLOYMENT_NAME="template-operator-v2-controller-manager"  # Hardcoded in the chart's deployment template

test_templateoperatorv2_cr() {
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

    # The chart defaults to certManager.enabled=true and renders cert-manager
    # Certificate/Issuer for the webhook serving cert, so cert-manager (and its
    # CRDs) must exist before the CR is applied.
    log_info "Installing cert-manager (required by the chart's webhook certificates)"
    if ! helm upgrade --install cert-manager cert-manager --repo https://charts.jetstack.io \
        --namespace cert-manager --create-namespace \
        --set crds.enabled=true --wait --timeout 5m; then
        log_error "Failed to install cert-manager"
        return 1
    fi

    # Apply the TemplateOperatorV2 CR
    log_info "Applying TemplateOperatorV2 Custom Resource"
    if ! apply_and_wait "$SCRIPT_DIR/../fixtures/template-operator-v2-test.yaml" "templateoperatorv2" "$CR_NAME"; then
        log_error "Failed to create TemplateOperatorV2 CR"
        return 1
    fi

    # Wait for the deployment to be created by the operator
    log_info "Waiting for template-operator-v2 deployment to be created"
    if ! wait_for_resource "deployment" "$DEPLOYMENT_NAME"; then
        log_error "template-operator-v2 deployment was not created"

        log_info "Checking for any deployments in namespace:"
        kubectl get deployments -n "$NAMESPACE" || true

        log_info "Checking TemplateOperatorV2 CR status:"
        kubectl describe templateoperatorv2 "$CR_NAME" -n "$NAMESPACE" || true

        return 1
    fi

    # Validate deployment is ready
    log_info "Waiting for template-operator-v2 deployment to be ready"
    if ! wait_for_deployment_ready "$DEPLOYMENT_NAME"; then
        log_error "template-operator-v2 deployment did not become ready"

        log_info "Deployment status:"
        kubectl describe deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" || true

        log_info "Pod status:"
        kubectl get pods -l app.kubernetes.io/name=template-operator-v2 -n "$NAMESPACE" || true

        log_info "Pod logs (if available):"
        local pods
        pods=$(kubectl get pods -l app.kubernetes.io/name=template-operator-v2 -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
        for pod in $pods; do
            if [ -n "$pod" ]; then
                log_info "Logs for pod $pod:"
                kubectl logs "$pod" -n "$NAMESPACE" --tail=20 || true
            fi
        done

        return 1
    fi

    # Check that the template-operator-v2 CRDs were installed by the chart
    log_info "Checking template-operator-v2 CRDs"
    for crd in templates.templates.v2.stakater.com templateinstances.templates.v2.stakater.com; do
        if kubectl get crd "$crd" &> /dev/null; then
            log_success "CRD $crd installed"
        else
            log_error "CRD $crd was not installed"
            return 1
        fi
    done

    # Check that the sync-enforcement webhook configuration was created
    log_info "Checking for the sync-enforcement ValidatingWebhookConfiguration"
    if kubectl get validatingwebhookconfigurations -o name | grep -q "sync-enforcement"; then
        log_success "sync-enforcement ValidatingWebhookConfiguration created"
    else
        log_warning "sync-enforcement ValidatingWebhookConfiguration not found"
    fi

    # Check that the metrics service was created
    log_info "Checking for template-operator-v2 metrics service"
    if ! wait_for_resource "service" "${DEPLOYMENT_NAME}-ms"; then
        log_warning "template-operator-v2 metrics service was not created (this might be expected depending on configuration)"
    else
        log_success "template-operator-v2 metrics service created successfully"
    fi

    local end_time
    end_time=$(date +%s)

    log_success "$TEST_NAME completed successfully"
    print_test_summary "$TEST_NAME" "$start_time" "$end_time" "PASSED"

    return 0
}

cleanup_templateoperatorv2_test() {
    log_info "Cleaning up TemplateOperatorV2 test resources"
    kubectl delete templateoperatorv2 "$CR_NAME" -n "$NAMESPACE" --ignore-not-found=true || true
    helm uninstall cert-manager -n cert-manager || true
    cleanup_test_namespace
}

# Main execution
main() {
    local test_result=0

    # Set trap for cleanup on exit
    trap cleanup_templateoperatorv2_test EXIT

    # Run the test
    if ! test_templateoperatorv2_cr; then
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
