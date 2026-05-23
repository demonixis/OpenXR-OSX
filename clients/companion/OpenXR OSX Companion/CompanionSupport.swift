// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation
import UniformTypeIdentifiers

enum EncoderPreset: String, CaseIterable, Identifiable {
    case quality
    case balanced
    case speed

    var id: String { rawValue }
}

enum StreamingTransportSetting: String, CaseIterable, Identifiable {
    case auto
    case wifi
    case usbAdb = "usb_adb"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto:
            return "Auto"
        case .wifi:
            return "WiFi"
        case .usbAdb:
            return "USB ADB"
        }
    }
}

struct CompanionPaths {
    static let appSupportDirectory = NSString(string: "~/Library/Application Support/OpenXR-OSX").expandingTildeInPath
    static let configFilePath = (appSupportDirectory as NSString).appendingPathComponent("openxr_osx.toml")
    static let launcherAppsPath = (appSupportDirectory as NSString).appendingPathComponent("launcher_apps.json")
    static let installedRuntimeDirectory = (appSupportDirectory as NSString).appendingPathComponent("Runtime/current")
    static let installedRuntimeManifestPath = (installedRuntimeDirectory as NSString).appendingPathComponent("openxr_osx.json")
    static let terminalScriptsDirectory = (appSupportDirectory as NSString).appendingPathComponent("TerminalLaunchers")
    static let activeRuntimeDirectory = NSString(string: "~/.config/openxr/1").expandingTildeInPath
    static let activeRuntimePath = (activeRuntimeDirectory as NSString).appendingPathComponent("active_runtime.json")
    static let launchAgentsDirectory = NSString(string: "~/Library/LaunchAgents").expandingTildeInPath
    static let launchAgentPath = (launchAgentsDirectory as NSString).appendingPathComponent("com.openxr_osx.runtime_env.plist")

    static var bundledRuntimeDirectoryURL: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("OpenXRRuntime", isDirectory: true)
    }
}

struct RuntimeRegistrationStatus {
    var activeRuntimeExists = false
    var activeRuntimeTarget: String?
}

struct QuestUsbDevice: Identifiable, Equatable {
    let serial: String
    let state: String
    let details: String

    var id: String { serial }
    var isUsable: Bool { state == "device" }
    var displayName: String {
        if details.isEmpty {
            return "\(serial) (\(state))"
        }
        return "\(serial) (\(state)) \(details)"
    }
}

enum QuestUsbBridge {
    static let reversePorts = [9944, 9945, 9946]

    static func devices() throws -> [QuestUsbDevice] {
        let adb = try adbExecutablePath()
        return try parseDevices(Shell.run(adb, ["devices", "-l"]))
    }

    @discardableResult
    static func configureReverse(for serial: String) throws -> Set<Int> {
        let adb = try adbExecutablePath()
        for port in reversePorts {
            _ = try? Shell.run(adb, ["-s", serial, "reverse", "--remove", "tcp:\(port)"])
        }
        for port in reversePorts {
            _ = try Shell.run(adb, ["-s", serial, "reverse", "tcp:\(port)", "tcp:\(port)"])
        }
        let configuredPorts = try reverseMappings(for: serial)
        let missingPorts = reversePorts.filter { !configuredPorts.contains($0) }
        if !missingPorts.isEmpty {
            throw QuestUsbBridgeError.missingReversePorts(missingPorts)
        }
        return configuredPorts
    }

    static func reverseMappings(for serial: String) throws -> Set<Int> {
        let adb = try adbExecutablePath()
        return parseReversePorts(try Shell.run(adb, ["-s", serial, "reverse", "--list"]))
    }

    static func adbExecutablePath() throws -> String {
        if let path = resolveAdbExecutablePath() {
            return path
        }
        throw QuestUsbBridgeError.adbNotFound
    }

    static func resolveAdbExecutablePath(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: String = NSHomeDirectory()
    ) -> String? {
        let fileManager = FileManager.default
        for candidate in adbCandidatePaths(environment: environment, homeDirectory: homeDirectory) {
            if fileManager.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        if let shellPath = try? Shell.run("/bin/zsh", ["-lc", "command -v adb"]),
           !shellPath.isEmpty,
           fileManager.isExecutableFile(atPath: shellPath) {
            return shellPath
        }

        return nil
    }

    static func adbCandidatePaths(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: String = NSHomeDirectory()
    ) -> [String] {
        var paths: [String] = []
        func append(_ path: String?) {
            guard let path, !path.isEmpty, !paths.contains(path) else { return }
            paths.append(path)
        }

        append(environment["ANDROID_HOME"].map { "\($0)/platform-tools/adb" })
        append(environment["ANDROID_SDK_ROOT"].map { "\($0)/platform-tools/adb" })
        append("\(homeDirectory)/Library/Android/sdk/platform-tools/adb")
        append("/opt/homebrew/bin/adb")
        append("/usr/local/bin/adb")

        if let pathEnvironment = environment["PATH"] {
            for directory in pathEnvironment.split(separator: ":") {
                append("\(directory)/adb")
            }
        }

        return paths
    }

    static func parseDevices(_ output: String) -> [QuestUsbDevice] {
        output
            .split(whereSeparator: { $0.isNewline })
            .dropFirst()
            .compactMap { line -> QuestUsbDevice? in
                let parts = line.split(maxSplits: 2, omittingEmptySubsequences: true) {
                    $0 == " " || $0 == "\t"
                }
                guard parts.count >= 2 else {
                    return nil
                }
                let serial = String(parts[0])
                let state = String(parts[1])
                let details = parts.count >= 3 ? String(parts[2]) : ""
                return QuestUsbDevice(serial: serial, state: state, details: details)
            }
    }

    static func parseReversePorts(_ output: String) -> Set<Int> {
        var ports = Set<Int>()
        for line in output.split(whereSeparator: { $0.isNewline }) {
            let text = String(line)
            for port in reversePorts where text.contains("tcp:\(port) tcp:\(port)") {
                ports.insert(port)
            }
        }
        return ports
    }
}

enum QuestUsbBridgeError: LocalizedError {
    case adbNotFound
    case missingReversePorts([Int])

    var errorDescription: String? {
        switch self {
        case .adbNotFound:
            return "adb was not found from the Companion app. Install Android Platform Tools or make sure adb exists at /opt/homebrew/bin/adb, /usr/local/bin/adb, or ~/Library/Android/sdk/platform-tools/adb."
        case let .missingReversePorts(ports):
            let portList = ports.map(String.init).joined(separator: ", ")
            return "adb reverse did not report the expected mapping for port(s): \(portList)."
        }
    }
}

enum ShellCommandError: LocalizedError {
    case commandFailed(command: String, stderr: String, exitCode: Int32)

    var errorDescription: String? {
        switch self {
        case let .commandFailed(command, stderr, exitCode):
            let detail = stderr.isEmpty ? "command failed" : stderr
            return "\(command) exited with code \(exitCode): \(detail)"
        }
    }
}

enum Shell {
    @discardableResult
    static func run(_ launchPath: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw ShellCommandError.commandFailed(
                command: ([launchPath] + arguments).joined(separator: " "),
                stderr: error.trimmingCharacters(in: .whitespacesAndNewlines),
                exitCode: process.terminationStatus
            )
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum SourceDefaults {
    static func defaultRuntimeManifestPath(sourceFilePath: String = #filePath) -> String {
        let sourceURL = URL(fileURLWithPath: sourceFilePath)
        let repoRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return repoRoot.appendingPathComponent("build/runtime/openxr_osx.json").path
    }
}

func revealInFinder(_ path: String) {
    NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
}

func chooseJsonFile(startingAt path: String?) -> String? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.allowsMultipleSelection = false
    panel.allowedContentTypes = [.json]
    panel.prompt = "Choose Runtime JSON"
    if let path, !path.isEmpty {
        panel.directoryURL = URL(fileURLWithPath: (path as NSString).deletingLastPathComponent)
        panel.nameFieldStringValue = (path as NSString).lastPathComponent
    }
    return panel.runModal() == .OK ? panel.url?.path : nil
}

func chooseAppBundle(startingAt path: String?) -> URL? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.allowsMultipleSelection = false
    panel.allowedContentTypes = [.applicationBundle]
    panel.prompt = "Add App"
    if let path, !path.isEmpty {
        panel.directoryURL = URL(fileURLWithPath: (path as NSString).deletingLastPathComponent)
        panel.nameFieldStringValue = (path as NSString).lastPathComponent
    } else {
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
    }
    return panel.runModal() == .OK ? panel.url : nil
}

func normalizedPath(_ path: String) -> String {
    URL(fileURLWithPath: path).standardizedFileURL.path
}
