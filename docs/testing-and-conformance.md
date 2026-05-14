# Testing And Conformance

## Scope

This document covers the runtime test suite and the optional OpenXR-CTS lane.

## Runtime Tests

Build and run the default macOS checks with:

```bash
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build
ctest --test-dir build --output-on-failure
```

The default test layers are:

- `openxr_osx_tests`
- `openxr_osx_runtime_tests`

## CTS Lane

Enable and run the optional OpenXR-CTS lane with:

```bash
cmake -B build_cts -G Ninja -DCMAKE_BUILD_TYPE=Debug -DOPENXR_OSX_ENABLE_CTS=ON
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

- run the macOS build and tests
- run the Android build if Android code changed
- run the CTS lane when runtime API, extension behavior, swapchain handling, action handling, or conformance-sensitive behavior changed

## Documentation Updates

Update this file when:

- test commands change
- test targets change
- CTS reports move
- the tracked CTS baseline changes
