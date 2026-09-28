#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the async-swiftly open source project
##
## Copyright (c) 2026 Erik Basargin and the async-swiftly project authors
## SPDX-License-Identifier: MIT
##
## See LICENSE for license information
##
##===----------------------------------------------------------------------===##

set -euo pipefail

action='test'
case "${1:-}" in
    --skip-build) action='test-without-building'; shift ;;
    --help|-h)
        echo "Usage: bash scripts/stress.sh [--skip-build]"
        echo "Set STRESS_REPETITIONS to override the default of 10000."
        exit 0
        ;;
esac

if (( $# != 0 )); then
    echo "Usage: bash scripts/stress.sh [--skip-build]" >&2
    exit 2
fi

if [[ "$(uname -s)" != Darwin ]]; then
    echo "Stress testing requires macOS and Xcode." >&2
    exit 2
fi

repetitions=${STRESS_REPETITIONS:-10000}
if [[ ! "$repetitions" =~ ^[1-9][0-9]*$ ]]; then
    echo "STRESS_REPETITIONS must be a positive integer." >&2
    exit 2
fi

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
mkdir -p .build/stress
result_directory=$(mktemp -d "$PWD/.build/stress/run.XXXXXX")
result_bundle="$result_directory/results.xcresult"

echo "Running stress tests $repetitions times."
echo "Result bundle: $result_bundle"

exec xcodebuild "$action" \
    -scheme async-swiftly \
    -destination 'platform=macOS' \
    -only-testing-tags stress \
    -test-iterations "$repetitions" \
    -test-repetition-relaunch-enabled NO \
    -test-timeouts-enabled YES \
    -default-test-execution-time-allowance 5 \
    -maximum-test-execution-time-allowance 5 \
    -resultBundlePath "$result_bundle"
