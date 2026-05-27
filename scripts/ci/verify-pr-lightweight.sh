#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0

set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

RUN_ANDROID=1
RUN_HOME=1
RUN_SIMULATOR=1
RUN_VISIONOS=1

usage() {
    cat <<'EOF'
Usage: scripts/ci/verify-pr-lightweight.sh [options]

Run the same lightweight verification lanes used on pull requests:
  - Android client build
  - macOS Home app build
  - macOS simulator app build
  - visionOS player build

Options:
  --skip-android         Skip Android client build
  --skip-home            Skip macOS Home build
  --skip-simulator       Skip macOS simulator build
  --skip-visionos        Skip visionOS player build
  -h, --help             Show this help text
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-android)
            RUN_ANDROID=0
            shift
            ;;
        --skip-home)
            RUN_HOME=0
            shift
            ;;
        --skip-simulator)
            RUN_SIMULATOR=0
            shift
            ;;
        --skip-visionos)
            RUN_VISIONOS=0
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "unknown option: $1"
            ;;
    esac
done

if [[ "${RUN_ANDROID}" -eq 1 ]]; then
    run "${REPO_ROOT}/scripts/ci/build-android.sh"
fi

if [[ "${RUN_HOME}" -eq 1 ]]; then
    run "${REPO_ROOT}/scripts/ci/build-home.sh"
fi

if [[ "${RUN_SIMULATOR}" -eq 1 ]]; then
    run "${REPO_ROOT}/scripts/ci/build-simulator.sh"
fi

if [[ "${RUN_VISIONOS}" -eq 1 ]]; then
    run "${REPO_ROOT}/scripts/ci/build-visionos.sh"
fi
