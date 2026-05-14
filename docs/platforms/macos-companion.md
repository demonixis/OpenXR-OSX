# macOS Companion App

## Scope

The native macOS companion app lives in `clients/companion/` and provides a SwiftUI control surface for:

- editing `~/Library/Application Support/OpenXR-OSX/openxr_osx.toml`
- toggling `general.runtime_enabled` without unregistering the manifest
- registering or unregistering the per-user OpenXR runtime for GUI applications
- exposing those controls through a standard macOS app window

The App Store/TestFlight target is sandboxed and uses the `public.app-category.developer-tools`
category. Its entitlement file enables user-selected read/write file access so the archive satisfies
Mac App Store packaging validation.

The runtime registration workflow still needs direct access to:

- `~/Library/Application Support/OpenXR-OSX/openxr_osx.toml`
- `~/.config/openxr/1/active_runtime.json`
- `~/Library/LaunchAgents/com.openxr_osx.runtime_env.plist`
- `launchctl setenv` and `launchctl unsetenv`

Those paths are outside the app container, so packaged TestFlight builds may need user-granted file
access or a separate distribution path for full runtime registration behavior.

## Build

```bash
xcodebuild -project "clients/companion/OpenXR OSX Companion.xcodeproj" \
  -scheme "OpenXR OSX Companion" \
  -configuration Debug \
  build
```

## Runtime Registration Workflow

The companion app mirrors the logic previously exposed by `scripts/openxr_runtime_default.sh`, but the UI now centers on a single manifest path:

- `Enable OpenXR Registration` points `~/.config/openxr/1/active_runtime.json` to the selected runtime JSON path
- `Update OpenXR Registration` replaces an existing active runtime file or symlink with the selected runtime JSON path
- it also writes `~/Library/LaunchAgents/com.openxr_osx.runtime_env.plist`
- it refreshes `XR_RUNTIME_JSON` in the current GUI session through `launchctl`
- `Disable OpenXR Registration` removes the active runtime link and LaunchAgent for test scenarios

## Config Editing

The structured editor covers the current runtime keys:

- `general.runtime_enabled`
- `streaming.bitrate_mbps`
- `streaming.fov_degrees`
- `streaming.resolution_scale`
- `streaming.keyframe_interval_sec`
- `streaming.encoder_preset`
- `logging.file_logging`
- `logging.quest_logcat`

## Hot Reload Behavior

The runtime now reloads the config file when it notices that `openxr_osx.toml` changed on disk. The current behavior is intentionally scoped:

- `runtime_enabled` is applied to subsequent `xrCreateInstance` calls
- `fov_degrees` is picked up on subsequent view location work
- `keyframe_interval_sec` is picked up by the encode loop without restarting the process
- `quest_logcat` can start or stop adb capture after a config save
- `bitrate_mbps`, `resolution_scale`, and `encoder_preset` are read again when the streaming path or encoder is created, so they apply on reconnect or restart
- File logger sink setup still requires a restart because that resource is created during initialization

This keeps the reload path lightweight and avoids blocking frame submission.
