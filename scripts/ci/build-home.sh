#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0

set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

require_command xcodebuild

log "Building macOS Home app"
cd "${REPO_ROOT}"
CI_HOME="$(derived_data_path home)/home"
mkdir -p "${CI_HOME}"
run /usr/bin/env \
    HOME="${CI_HOME}" \
    xcodebuild \
    -project "clients/oxrsys-home/OXRSys Home.xcodeproj" \
    -scheme "OXRSys Home" \
    -configuration Debug \
    -derivedDataPath "$(derived_data_path home)" \
    CODE_SIGNING_ALLOWED=NO \
    build
