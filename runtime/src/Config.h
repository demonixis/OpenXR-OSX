// SPDX-License-Identifier: MPL-2.0

#pragma once

#include <chrono>
#include <filesystem>
#include <istream>
#include <mutex>
#include <string>

struct ConfigValues
{
    bool runtimeEnabled = true;     // Allow this runtime to accept xrCreateInstance
    uint32_t bitrateMbps = 50;      // H.265 encoding bitrate in Mbps
    uint32_t fovDegrees = 100;      // Rendering FOV in degrees (symmetric)
    float resolutionScale = 0.75f;  // Encode resolution multiplier (0.25-1.0)
    uint32_t keyframeIntervalSec = 2; // Seconds between forced keyframes
    std::string encoderPreset = "balanced"; // "quality", "balanced", "speed"
    std::string streamingTransport = "auto"; // "auto", "wifi", "usb_adb"

    bool fileLogging = true;        // Write logs to openxr_osx.log
    bool questLogcat = false;       // Capture Quest logcat to openxr_osx_quest.log
};

ConfigValues ParseConfigToml(std::istream& input, const ConfigValues& defaults = {});

/**
 * Runtime configuration loaded from ~/Library/Application Support/OpenXR-OSX/openxr_osx.toml
 * with a one-release fallback to the legacy dylib-local config file.
 *
 * Singleton initialized once on first access. Configures spdlog sinks
 * (console + optional rotating file) and optionally captures Quest logcat.
 *
 * Dynamic fields are reloaded opportunistically when the config file changes.
 * Logging sink changes still require a restart.
 */
class Config
{
public:
    static Config& Get();

    ConfigValues GetValues();
    void RefreshIfNeeded();

    // Resolved paths
    std::string appSupportDir;      // ~/Library/Application Support/OpenXR-OSX
    std::string dylibDir;           // Directory containing libopenxr_osx.dylib
    std::string configFilePath;     // Resolved config file path
    std::string logFilePath;        // Full path to openxr_osx.log
    std::string questLogFilePath;   // Full path to openxr_osx_quest.log

    void Shutdown();

private:
    Config();
    ~Config();

    Config(const Config&) = delete;
    Config& operator=(const Config&) = delete;

    void DetectDylibDir();
    void LoadConfigFile();
    void SetupLogging();
    bool ResolveConfigFilePath(std::string& resolvedPath, bool& fileExists) const;
    bool ReloadIfChangedLocked(bool force);
    void StartLogcatCapture();
    void StopLogcatCapture();

    mutable std::mutex mutex_;
    ConfigValues values_;
    std::filesystem::file_time_type lastConfigWriteTime_ = {};
    bool hasConfigFile_ = false;
    bool hasKnownWriteTime_ = false;
    std::chrono::steady_clock::time_point lastReloadCheck_ = std::chrono::steady_clock::time_point::min();
    FILE* logcatProcess_ = nullptr;
    FILE* logcatFile_ = nullptr;
    bool logcatRunning_ = false;
};
