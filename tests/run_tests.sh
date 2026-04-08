#!/bin/bash

# Main test runner for MTO Dependencies Operator tests
# This script runs all integration tests and provides a summary

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers/common.sh"

# Test configuration
TESTS_DIR="$SCRIPT_DIR/integration"
PARALLEL_TESTS="${PARALLEL_TESTS:-false}"
CLEANUP_ON_FAILURE="${CLEANUP_ON_FAILURE:-true}"

# Test results tracking
declare -a PASSED_TESTS=()
declare -a FAILED_TESTS=()
declare -a SKIPPED_TESTS=()

# Map user-friendly test names to actual test files
declare -A TEST_NAME_MAP=(
    ["dex"]="test_dex.sh"
    ["prometheus"]="test_prometheus.sh" 
    ["kube_state_metrics"]="test_kube_state_metrics.sh"
    ["kube-state-metrics"]="test_kube_state_metrics.sh"  # Allow both dash and underscore
    ["postgres"]="test_postgres.sh"
    ["postgresql"]="test_postgres.sh"  # Allow alternative naming
    ["opencost"]="test_opencost.sh"
    ["open-cost"]="test_opencost.sh"   # Allow dash variant
)

usage() {
    cat << EOF
Usage: $0 [OPTIONS] [TESTS...]

Run integration tests for MTO Dependencies Operator

OPTIONS:
    -h, --help              Show this help message
    -p, --parallel          Run tests in parallel (default: sequential)
    -n, --namespace NAME    Test namespace (default: mto-test)
    -t, --timeout SECONDS  Test timeout in seconds (default: 300)
    --cleanup-on-failure    Clean up resources on test failure (default: true)
    --no-cleanup-on-failure Don't clean up resources on test failure
    --list                  List available tests
    --dry-run              Show what tests would be run without executing them

TESTS:
    Specific test scripts to run (without .sh extension).
    If not specified, all available tests will be run.

EXAMPLES:
    $0                                    # Run all tests
    $0 dex prometheus                     # Run specific tests
    $0 --parallel                         # Run all tests in parallel
    $0 --namespace my-test-ns dex         # Run dex test in custom namespace
    $0 --timeout 600 prometheus          # Run prometheus test with 10min timeout

ENVIRONMENT VARIABLES:
    TEST_NAMESPACE          Test namespace (default: mto-test)
    TEST_TIMEOUT           Test timeout in seconds (default: 300)
    PARALLEL_TESTS         Run tests in parallel (true/false, default: false)
    CLEANUP_ON_FAILURE     Clean up on failure (true/false, default: true)
EOF
}

list_tests() {
    echo "Available tests:"
    for key in "${!TEST_NAME_MAP[@]}"; do
        echo "  $key"
    done | sort
}

parse_arguments() {
    local tests_to_run=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                # Handled in main function
                shift
                ;;
            --list)
                # Handled in main function
                shift
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            -p|--parallel)
                PARALLEL_TESTS="true"
                shift
                ;;
            -n|--namespace)
                export TEST_NAMESPACE="$2"
                shift 2
                ;;
            -t|--timeout)
                export TEST_TIMEOUT="$2"
                shift 2
                ;;
            --cleanup-on-failure)
                CLEANUP_ON_FAILURE="true"
                shift
                ;;
            --no-cleanup-on-failure)
                CLEANUP_ON_FAILURE="false"
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                tests_to_run+=("$1")
                shift
                ;;
        esac
    done
    
    # If no specific tests provided, run all
    if [ ${#tests_to_run[@]} -eq 0 ]; then
        for key in "${!TEST_NAME_MAP[@]}"; do
            tests_to_run+=("$key")
        done
    fi
    
    # Validate requested tests and convert to actual test files
    local validated_tests=()
    for test_name in "${tests_to_run[@]}"; do
        if [[ -n "${TEST_NAME_MAP[$test_name]}" ]]; then
            validated_tests+=("${TEST_NAME_MAP[$test_name]%.sh}")
        else
            echo "ERROR: Test '$test_name' not found. Available tests:" >&2
            for key in "${!TEST_NAME_MAP[@]}"; do
                echo "  $key" >&2
            done | sort >&2
            return 1
        fi
    done
    
    echo "${validated_tests[@]}"
}

run_single_test() {
    local test_name="$1"
    local test_script="$TESTS_DIR/${test_name}.sh"
    
    if [ ! -f "$test_script" ]; then
        log_error "Test script not found: $test_script"
        return 1
    fi
    
    if [ ! -x "$test_script" ]; then
        log_error "Test script not executable: $test_script"
        return 1
    fi
    
    log_info "Running test: $test_name"
    
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "DRY RUN: Would execute $test_script"
        return 0
    fi
    
    local start_time
    start_time=$(date +%s)
    
    # Create a unique namespace for each test to avoid conflicts
    local test_namespace
    test_namespace="${TEST_NAMESPACE:-mto-test}-${test_name}"
    # Replace underscores with dashes for valid Kubernetes names
    test_namespace="${test_namespace//_/-}"
    
    # Run the test
    if env TEST_NAMESPACE="$test_namespace" DRY_RUN="${DRY_RUN:-false}" "$test_script"; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        PASSED_TESTS+=("$test_name (${duration}s)")
        log_success "Test $test_name PASSED in ${duration}s"
        return 0
    else
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        FAILED_TESTS+=("$test_name (${duration}s)")
        log_error "Test $test_name FAILED in ${duration}s"
        
        if [ "$CLEANUP_ON_FAILURE" = "false" ]; then
            log_warning "Skipping cleanup for failed test $test_name (resources left for debugging)"
        fi
        
        return 1
    fi
}

run_tests_sequential() {
    local tests=("$@")
    local overall_result=0
    
    log_info "Running ${#tests[@]} tests sequentially"
    
    for test_name in "${tests[@]}"; do
        if ! run_single_test "$test_name"; then
            overall_result=1
            if [ "${FAIL_FAST:-false}" = "true" ]; then
                log_error "Stopping tests due to failure (FAIL_FAST=true)"
                break
            fi
        fi
        echo ""  # Add spacing between tests
    done
    
    return $overall_result
}

run_tests_parallel() {
    local tests=("$@")
    local pids=()
    local overall_result=0
    
    log_info "Running ${#tests[@]} tests in parallel"
    
    # Start all tests in background
    for test_name in "${tests[@]}"; do
        run_single_test "$test_name" &
        pids+=($!)
    done
    
    # Wait for all tests to complete
    for i in "${!pids[@]}"; do
        local pid=${pids[$i]}
        local test_name=${tests[$i]}
        
        if wait $pid; then
            log_success "Parallel test $test_name completed successfully"
        else
            log_error "Parallel test $test_name failed"
            overall_result=1
        fi
    done
    
    return $overall_result
}

print_final_summary() {
    local overall_result="$1"
    local total_tests=$((${#PASSED_TESTS[@]} + ${#FAILED_TESTS[@]} + ${#SKIPPED_TESTS[@]}))
    
    echo ""
    echo "========================================"
    echo "TEST SUMMARY"
    echo "========================================"
    echo "Total tests: $total_tests"
    echo "Passed: ${#PASSED_TESTS[@]}"
    echo "Failed: ${#FAILED_TESTS[@]}"
    echo "Skipped: ${#SKIPPED_TESTS[@]}"
    echo ""
    
    if [ ${#PASSED_TESTS[@]} -gt 0 ]; then
        echo "PASSED TESTS:"
        for test in "${PASSED_TESTS[@]}"; do
            echo "  ✓ $test"
        done
        echo ""
    fi
    
    if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
        echo "FAILED TESTS:"
        for test in "${FAILED_TESTS[@]}"; do
            echo "  ✗ $test"
        done
        echo ""
    fi
    
    if [ ${#SKIPPED_TESTS[@]} -gt 0 ]; then
        echo "SKIPPED TESTS:"
        for test in "${SKIPPED_TESTS[@]}"; do
            echo "  - $test"
        done
        echo ""
    fi
    
    if [ $overall_result -eq 0 ]; then
        log_success "ALL TESTS PASSED"
    else
        log_error "SOME TESTS FAILED"
    fi
    
    echo "========================================"
}

main() {
    local start_time
    start_time=$(date +%s)
    
    # Handle special flags that should exit early
    for arg in "$@"; do
        case $arg in
            -h|--help)
                usage
                exit 0
                ;;
            --list)
                list_tests
                exit 0
                ;;
        esac
    done
    
    # Parse command line arguments
    local tests_to_run_string
    tests_to_run_string=$(parse_arguments "$@")
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    local tests_to_run
    IFS=' ' read -ra tests_to_run <<< "$tests_to_run_string"
    
    log_info "MTO Dependencies Operator Integration Tests"
    log_info "Test namespace: ${TEST_NAMESPACE:-mto-test}"
    log_info "Test timeout: ${TEST_TIMEOUT:-300}s"
    log_info "Parallel execution: $PARALLEL_TESTS"
    log_info "Cleanup on failure: $CLEANUP_ON_FAILURE"
    echo ""
    
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "DRY RUN MODE - No tests will actually be executed"
        echo ""
    fi
    
    # Check prerequisites
    if [ "${DRY_RUN:-false}" != "true" ]; then
        if ! check_prerequisites; then
            log_error "Prerequisites check failed"
            exit 1
        fi
        echo ""
    fi
    
    # Run tests
    local overall_result=0
    if [ "$PARALLEL_TESTS" = "true" ]; then
        if ! run_tests_parallel "${tests_to_run[@]}"; then
            overall_result=1
        fi
    else
        if ! run_tests_sequential "${tests_to_run[@]}"; then
            overall_result=1
        fi
    fi
    
    # Print summary
    local end_time
    end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    echo ""
    print_final_summary $overall_result
    echo "Total execution time: ${total_duration}s"
    
    exit $overall_result
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi