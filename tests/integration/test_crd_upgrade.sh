#!/bin/bash

# A FinOpsOperator must install over a CRD that already existed before the
# operator pod started, keep every instance of that CRD, and bring its schema
# up to date.
#
# This is the state of any cluster upgrading MDO: the CRDs are already there,
# customers have instances under them, and the operator pod runs in a
# different namespace than the CRs it reconciles.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../helpers/common.sh"

TEST_NAME="CRD upgrade keeps instances"
CR_NAME="crd-upgrade-test"
CRD_NAME="costjobs.finops.stakater.com"
UNUSED_CRD_NAME="clients.auth.stakater.com"
INSTANCE_NAME="customer-costjob"
OPERATOR_NS="${OPERATOR_NAMESPACE:-mto-dependencies-operator-system}"

restart_operator() {
    local deployment
    deployment=$(get_operator_deployment_name)
    log_info "Restarting operator $OPERATOR_NS/$deployment so it starts with the CRD already present"
    kubectl rollout restart deployment "$deployment" -n "$OPERATOR_NS"
    kubectl rollout status deployment "$deployment" -n "$OPERATOR_NS" --timeout="${TIMEOUT}s"
}

wait_for_release_deployed() {
    local counter=0
    while true; do
        local deployed
        deployed=$(kubectl get finopsoperator "$CR_NAME" -n "$NAMESPACE" \
            -o jsonpath='{.status.conditions[?(@.type=="Deployed")].status}' 2>/dev/null)
        if [ "$deployed" = "True" ]; then
            log_success "FinOpsOperator $CR_NAME release deployed"
            return 0
        fi
        if [ $counter -ge $TIMEOUT ]; then
            log_error "FinOpsOperator $CR_NAME release did not deploy"
            kubectl get finopsoperator "$CR_NAME" -n "$NAMESPACE" -o jsonpath='{.status.conditions}' || true
            echo
            return 1
        fi
        sleep $CHECK_INTERVAL
        counter=$((counter + CHECK_INTERVAL))
    done
}

test_crd_upgrade() {
    local start_time
    start_time=$(date +%s)

    log_info "Starting $TEST_NAME"

    if ! check_prerequisites; then
        return 1
    fi
    check_operator_running
    create_test_namespace

    if [ "$OPERATOR_NS" = "$NAMESPACE" ]; then
        log_error "Operator namespace and test namespace must differ for this test to mean anything"
        return 1
    fi

    log_info "Pre-creating stale $CRD_NAME and a customer instance"
    kubectl apply -f "$SCRIPT_DIR/../fixtures/costjobs-crd-stale.yaml"
    kubectl wait --for=condition=Established "crd/$CRD_NAME" --timeout=60s
    kubectl apply -f "$SCRIPT_DIR/../fixtures/costjob-instance.yaml" -n "$NAMESPACE"

    # The CR exists before the pod restarts, as on any cluster upgrading MDO.
    log_info "Applying FinOpsOperator $CR_NAME"
    kubectl apply -f "$SCRIPT_DIR/../fixtures/finops-operator-crd-upgrade.yaml" -n "$NAMESPACE"

    restart_operator

    if ! wait_for_release_deployed; then
        return 1
    fi

    # No test creates a DexConfigOperator, so its CRDs must not appear: the
    # operator applies CRDs only for charts that have a CR.
    log_info "Checking no CRD was applied for a chart without a CR"
    if kubectl get crd "$UNUSED_CRD_NAME" &> /dev/null; then
        log_error "$UNUSED_CRD_NAME was created although no DexConfigOperator exists"
        return 1
    fi
    log_success "$UNUSED_CRD_NAME not created"

    log_info "Checking the customer instance survived"
    if ! kubectl get costjob "$INSTANCE_NAME" -n "$NAMESPACE" &> /dev/null; then
        log_error "CostJob $INSTANCE_NAME was lost"
        return 1
    fi
    log_success "CostJob $INSTANCE_NAME survived"

    log_info "Checking $CRD_NAME carries the current schema"
    local sharding
    sharding=$(kubectl get crd "$CRD_NAME" \
        -o jsonpath='{.spec.versions[0].schema.openAPIV3Schema.properties.spec.properties.sharding.type}')
    if [ "$sharding" != "object" ]; then
        log_error "$CRD_NAME still has the stale schema (spec.sharding missing)"
        return 1
    fi
    log_success "$CRD_NAME schema upgraded"

    local end_time
    end_time=$(date +%s)
    print_test_summary "$TEST_NAME" "$start_time" "$end_time" "PASSED"
    return 0
}

cleanup_crd_upgrade_test() {
    log_info "Cleaning up $TEST_NAME resources"
    delete_cr_and_wait "finopsoperator" "$CR_NAME" || true
    kubectl delete costjob "$INSTANCE_NAME" -n "$NAMESPACE" --ignore-not-found || true
    # The release keeps its CRDs on uninstall, so drop the one this test seeded
    # to give a repeat run the same starting state.
    kubectl delete crd "$CRD_NAME" --ignore-not-found || true
    cleanup_test_namespace || true
}

main() {
    local test_result=0
    trap cleanup_crd_upgrade_test EXIT

    if ! test_crd_upgrade; then
        test_result=1
        log_error "$TEST_NAME FAILED"
    else
        log_success "$TEST_NAME PASSED"
    fi

    return $test_result
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
