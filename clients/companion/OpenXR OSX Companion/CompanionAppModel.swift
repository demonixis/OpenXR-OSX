// SPDX-License-Identifier: MPL-2.0

import Combine
import Foundation

@MainActor
final class CompanionAppModel: ObservableObject {
    @Published var runtimeManifestPath: String
    @Published var serverConfig = OpenXRServerConfig()
    @Published var runtimeStatus = RuntimeRegistrationStatus()
    @Published var statusMessage = ""
    @Published var errorMessage: String?

    private let fileManager = FileManager.default
    private let defaults = UserDefaults.standard
    private let runtimeManifestPathKey = "runtimeManifestPath"
    private var currentConfigText = OpenXRServerConfig.defaultText
    private var lastKnownConfigModificationDate: Date?
    private var pollTask: Task<Void, Never>?

    init() {
        runtimeManifestPath = defaults.string(forKey: runtimeManifestPathKey) ?? SourceDefaults.defaultRuntimeManifestPath()
        loadAll()
        startPolling()
    }

    deinit {
        pollTask?.cancel()
    }

    var configFilePath: String {
        CompanionPaths.configFilePath
    }

    var activeRuntimePath: String {
        CompanionPaths.activeRuntimePath
    }

    var isRuntimeRegistered: Bool {
        runtimeStatus.activeRuntimeExists
    }

    var isSelectedRuntimeRegistered: Bool {
        guard let target = runtimeStatus.activeRuntimeTarget else {
            return false
        }
        return normalizedPath(target) == normalizedPath(runtimeManifestPath)
    }

    var registrationButtonTitle: String {
        if isSelectedRuntimeRegistered {
            return "Disable OpenXR Registration"
        }
        if isRuntimeRegistered {
            return "Update OpenXR Registration"
        }
        return "Enable OpenXR Registration"
    }

    func loadAll() {
        loadConfigFromDisk()
        refreshRuntimeStatus()
    }

    func loadConfigFromDisk() {
        do {
            if fileManager.fileExists(atPath: configFilePath) {
                currentConfigText = try String(contentsOfFile: configFilePath, encoding: .utf8)
                lastKnownConfigModificationDate = configModificationDate()
            } else {
                currentConfigText = OpenXRServerConfig.defaultText
                lastKnownConfigModificationDate = nil
            }
            serverConfig = OpenXRServerConfig.parse(from: currentConfigText)
        } catch {
            errorMessage = "Failed to load config: \(error.localizedDescription)"
        }
    }

    func saveStructuredConfig() {
        do {
            let directory = (configFilePath as NSString).deletingLastPathComponent
            try fileManager.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: nil)
            let text = serverConfig.merged(into: currentConfigText)
            try text.write(toFile: configFilePath, atomically: true, encoding: .utf8)
            currentConfigText = text
            lastKnownConfigModificationDate = configModificationDate()
            statusMessage = "Saved runtime configuration."
        } catch {
            errorMessage = "Failed to save config: \(error.localizedDescription)"
        }
    }

    func resetToDisk() {
        loadConfigFromDisk()
        statusMessage = "Reloaded configuration from disk."
    }

    func chooseRuntimeManifest() {
        if let selected = chooseJsonFile(startingAt: runtimeManifestPath) {
            runtimeManifestPath = selected
            defaults.set(selected, forKey: runtimeManifestPathKey)
            statusMessage = "Updated runtime manifest path."
        }
    }

    func refreshRuntimeStatus() {
        var status = RuntimeRegistrationStatus()
        status.activeRuntimeExists = activeRuntimeItemExists()
        if status.activeRuntimeExists {
            status.activeRuntimeTarget = destinationOfSymbolicLink(atPath: activeRuntimePath) ?? activeRuntimePath
        }
        runtimeStatus = status
    }

    func toggleRuntimeRegistration() {
        if isSelectedRuntimeRegistered {
            unregisterRuntime()
        } else {
            registerRuntime()
        }
    }

    func registerRuntime() {
        defaults.set(runtimeManifestPath, forKey: runtimeManifestPathKey)

        do {
            let manifestPath = normalizedPath(runtimeManifestPath)
            guard fileManager.fileExists(atPath: manifestPath) else {
                throw NSError(
                    domain: "OpenXROSXCompanion",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Runtime JSON not found at \(manifestPath)"]
                )
            }

            try fileManager.createDirectory(
                atPath: CompanionPaths.activeRuntimeDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            let wasRuntimeRegistered = activeRuntimeItemExists()
            if wasRuntimeRegistered {
                try fileManager.removeItem(atPath: activeRuntimePath)
            }
            try fileManager.createSymbolicLink(atPath: activeRuntimePath, withDestinationPath: manifestPath)

            try fileManager.createDirectory(
                atPath: CompanionPaths.launchAgentsDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            let launchAgent = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>Label</key>
                <string>com.openxr_osx.runtime_env</string>
                <key>ProgramArguments</key>
                <array>
                    <string>/bin/launchctl</string>
                    <string>setenv</string>
                    <string>XR_RUNTIME_JSON</string>
                    <string>\(manifestPath)</string>
                </array>
                <key>RunAtLoad</key>
                <true/>
            </dict>
            </plist>
            """
            try launchAgent.write(toFile: CompanionPaths.launchAgentPath, atomically: true, encoding: .utf8)

            _ = try? Shell.run("/bin/launchctl", ["unload", CompanionPaths.launchAgentPath])
            _ = try Shell.run("/bin/launchctl", ["load", CompanionPaths.launchAgentPath])
            _ = try Shell.run("/bin/launchctl", ["setenv", "XR_RUNTIME_JSON", manifestPath])

            refreshRuntimeStatus()
            statusMessage = wasRuntimeRegistered ? "Updated the OpenXR runtime registration." : "Registered the OpenXR runtime."
        } catch {
            errorMessage = "Failed to register runtime: \(error.localizedDescription)"
        }
    }

    func unregisterRuntime() {
        do {
            if activeRuntimeItemExists() {
                try fileManager.removeItem(atPath: activeRuntimePath)
            }
            _ = try? Shell.run("/bin/launchctl", ["unsetenv", "XR_RUNTIME_JSON"])
            _ = try? Shell.run("/bin/launchctl", ["unload", CompanionPaths.launchAgentPath])
            if fileManager.fileExists(atPath: CompanionPaths.launchAgentPath) {
                try fileManager.removeItem(atPath: CompanionPaths.launchAgentPath)
            }

            refreshRuntimeStatus()
            statusMessage = "Unregistered the OpenXR runtime."
        } catch {
            errorMessage = "Failed to unregister runtime: \(error.localizedDescription)"
        }
    }

    private func destinationOfSymbolicLink(atPath path: String) -> String? {
        guard let destination = try? fileManager.destinationOfSymbolicLink(atPath: path) else {
            return nil
        }
        if destination.hasPrefix("/") {
            return destination
        }
        let baseURL = URL(fileURLWithPath: path).deletingLastPathComponent()
        return baseURL.appendingPathComponent(destination).path
    }

    private func activeRuntimeItemExists() -> Bool {
        fileManager.fileExists(atPath: activeRuntimePath) || destinationOfSymbolicLink(atPath: activeRuntimePath) != nil
    }

    private func configModificationDate() -> Date? {
        let attributes = try? fileManager.attributesOfItem(atPath: configFilePath)
        return attributes?[.modificationDate] as? Date
    }

    private func startPolling() {
        pollTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                self.refreshRuntimeStatus()
                self.pollConfigChangesIfNeeded()
            }
        }
    }

    private func pollConfigChangesIfNeeded() {
        let currentDate = configModificationDate()
        guard currentDate != lastKnownConfigModificationDate else {
            return
        }
        loadConfigFromDisk()
    }
}
