# Testing And Conformance

## Scope

This document covers the local verification entry points, the runtime test suite, Home support tests, and the optional OpenXR-CTS lane.

## Local CI Reproduction

The repository keeps CI logic in checked-in scripts so pull request checks can be reproduced locally.

Use the lightweight PR wrapper to run the always-on lanes:

```bash
scripts/ci/verify-pr-lightweight.sh
```

By default that runs:

- Android client build
- macOS Home app build
- macOS simulator app build
- visionOS player build

Useful flags:

- `--skip-android` if you only need Apple-side validation
- `--skip-visionos` if the local Xcode install does not include visionOS simulator support

The standalone `scripts/ci/build-visionos.sh` lane probes for visionOS platform support before building. In CI it may download that platform automatically when the hosted image is missing it. Locally it fails with the exact install command unless `OPENXR_OSX_ALLOW_VISIONOS_PLATFORM_DOWNLOAD=1` is set.

If the script gets past that probe and then fails inside `xcodebuild`, treat that as a normal Xcode or CoreSimulator environment problem rather than a missing platform problem.

For the heavier runtime lane that is required when runtime-sensitive paths change, run:

```bash
scripts/ci/verify-macos-runtime-heavy.sh
```

That script bootstraps the Metal Toolchain and Vulkan host prerequisites unless `OPENXR_OSX_SKIP_HOST_BOOTSTRAP=1` is already suitable for the machine you are using.

The macOS Home also has targeted support tests that should be run when its launcher or runtime registration paths change.
In GitHub Actions, the heavy workflow still evaluates on every pull request so the required check stays visible to branch protection. It only runs the expensive macOS runtime job when runtime-sensitive paths changed.

## Runtime Tests

Build and run the default macOS checks with:

```bash
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build
ctest --test-dir build --output-on-failure
```

The default test layers are:

- `oxrsys_runtime_tests`
- `oxrsys_runtime_api_tests`

## Home Tests

The macOS Home has a small Swift test runner for bundle inspection, launcher persistence
merging, installed runtime manifest generation, preference persistence, and Terminal command
quoting:

```bash
swiftc -parse-as-library \
  "clients/oxrsys-home/OXRSys Home/HomeSupport.swift" \
  "clients/oxrsys-home/OXRSys Home/OXRSysServerConfig.swift" \
  "clients/oxrsys-home/OXRSys Home/HomeLauncher.swift" \
  "clients/oxrsys-home/OXRSys Home/HomePreferences.swift" \
  tests/HomeLauncherTests.swift \
  -o /tmp/oxrsys_home_launcher_tests && /tmp/oxrsys_home_launcher_tests
```

## CTS Lane

Enable and run the optional OpenXR-CTS lane with:

```bash
cmake -B build_cts -G Ninja -DCMAKE_BUILD_TYPE=Debug -DOXRSYS_ENABLE_CTS=ON
cmake --build build_cts --target openxr_cts_run
```

Reports:

- `build_cts/reports/openxr-cts/baseline.txt`
- `build_cts/reports/openxr-cts/automated_metal.xml`

## Current Baseline

As of March 17, 2026, the pinned non-interactive baseline is:

- 63 passed
- 36 skipped
- 0 failed

## Merge Expectations

Before considering a change ready:

- run `scripts/ci/verify-pr-lightweight.sh` for the always-on pull request lanes (covers macOS Home, simulator, visionOS, and Android builds)
- run `scripts/ci/verify-macos-runtime-heavy.sh` when runtime-sensitive files changed
- run the Home Swift test runner when changing the Home launcher, preferences, or runtime installer
- run the CTS lane when runtime API, extension behavior, swapchain handling, action handling, or conformance-sensitive behavior changed

## Documentation Updates

Update this file when:

- local CI reproduction commands change
- test commands change
- test targets change
- CTS reports move
- the tracked CTS baseline changes
