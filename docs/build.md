# Build

## Scope

This document is the entry point for build workflows. Installation steps live in [install.md](install.md). Platform-specific steps live under `docs/platforms/`.

## Before You Build

- Install the required tools first: [install.md](install.md)
- The checked-in Xcode projects intentionally do not contain a personal Apple development team.
  Select your own team in Xcode, or pass `DEVELOPMENT_TEAM=<team-id>` to `xcodebuild` when building
  targets that require Apple signing.
- For Xcode UI work on multiple Swift clients, open `clients/OpenXR Clients.xcworkspace`
  instead of opening the individual `.xcodeproj` files in separate windows. The simulator and
  visionOS targets share the local `OpenXRStreaming` Swift package, and one workspace avoids Xcode
  loading that package from multiple project containers.
- Use the platform pages for client-specific build and deployment details:
  - [Quest](platforms/quest.md)
  - [iOS Viewer](platforms/ios-viewer.md)
  - [Simulator](simulator.md)
  - [Vision OS](platforms/visionos.md)
  - [macOS Companion](platforms/macos-companion.md)

## Build The macOS Runtime

```bash
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build
ctest --test-dir build --output-on-failure
```

Key outputs:

- `build/runtime/libopenxr_osx.dylib`
- `build/runtime/openxr_osx.json`
- `build/runtime/openxr_osx.toml`
- `compile_commands.json` symlinked at the project root for editor integration

All third-party C++ dependencies are fetched through CMake `FetchContent`.

## Run The Runtime

For terminal-launched applications:

```bash
export XR_RUNTIME_JSON=$(pwd)/build/runtime/openxr_osx.json
```

For GUI applications such as Unity, Steam, or Godot launched outside a shell:

```bash
./scripts/openxr_runtime_default.sh set
./scripts/openxr_runtime_default.sh status
./scripts/openxr_runtime_default.sh unset
```

The helper creates `~/.config/openxr/1/active_runtime.json` and installs a per-user LaunchAgent that restores `XR_RUNTIME_JSON` for GUI sessions.

### Native macOS Companion App

The SwiftUI companion app provides a native control surface for the server TOML and the per-user runtime registration workflow:

```bash
xcodebuild -project "clients/companion/OpenXR OSX Companion.xcodeproj" \
  -scheme "OpenXR OSX Companion" \
  -configuration Debug \
  build
```

The macOS target is configured for App Store/TestFlight packaging with a developer tools category
and sandbox entitlements. See [macos-companion.md](platforms/macos-companion.md) for the app-specific
workflow, sandbox limits, and the current hot reload scope.

### Unified Viewer App

The unified viewer target under `clients/simulator/` now covers both the local simulator workflow and the iOS stereo viewer workflow:

```bash
xcodebuild -project "clients/simulator/OpenXR Simulator.xcodeproj" \
  -scheme "OpenXR Simulator" \
  -configuration Debug \
  -destination 'platform=macOS' \
  build
```

Optional iOS build:

```bash
xcodebuild -project "clients/simulator/OpenXR Simulator.xcodeproj" \
  -scheme "OpenXR Simulator" \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  build
```

See [simulator.md](simulator.md) for the simulator mode details and [ios-viewer.md](platforms/ios-viewer.md) for the `StereoView` workflow.

### Vision OS Viewer

The native visionOS viewer under `clients/visionos/` reuses the shared streaming package for discovery, decode, and transport:

```bash
xcodebuild -project "clients/visionos/Vision Player.xcodeproj" \
  -scheme "Vision Player" \
  -configuration Debug \
  -destination 'generic/platform=visionOS Simulator' \
  build
```

See [visionos.md](platforms/visionos.md) for the current workflow and limits.

For TestFlight, archive with `-destination 'generic/platform=visionOS'`. The visionOS target does
not use macOS-only `LSApplicationCategoryType` or App Sandbox settings.

### Unity Editor Helper

If you want to force the runtime only inside a Unity project, use the editor helper documented in [scripts/README.md](../scripts/README.md). It provides `Tools/OpenXR` menu entries to select and apply a runtime JSON for the current Unity editor session.

## Platform Pages

- Quest Android client: [quest.md](platforms/quest.md)
- Unified simulator/viewer app: [simulator.md](simulator.md)
- iOS `StereoView` workflow: [ios-viewer.md](platforms/ios-viewer.md)
- visionOS viewer: [visionos.md](platforms/visionos.md)
- macOS companion app: [macos-companion.md](platforms/macos-companion.md)

## Troubleshooting

- If a GUI app does not pick up the runtime, use `scripts/openxr_runtime_default.sh` instead of relying on shell startup files.
- If Android tooling is not found, verify `clients/android-openxr/local.properties`, Java 17, and the installed SDK/NDK versions described in [install.md](install.md).
- If the runtime is not discovered, check that `XR_RUNTIME_JSON` or `~/.config/openxr/1/active_runtime.json` points to `build/runtime/openxr_osx.json`.
- If Xcode cannot execute the `metal` tool, install the Metal Toolchain component as described in [install.md](install.md).
- If simulator builds fail with a `CoreSimulator` version mismatch, update Xcode and the simulator runtime components together.
