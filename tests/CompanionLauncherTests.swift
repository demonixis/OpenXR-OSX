// SPDX-License-Identifier: MPL-2.0

import Foundation

struct CompanionLauncherTestFailure: Error, CustomStringConvertible {
    let description: String
}

@main
struct CompanionLauncherTests {
    static func main() throws {
        try testBundleInspection()
        try testLauncherMergeDeduplicatesManualApps()
        try testRuntimeManifestGeneration()
        try testTerminalScriptQuoting()
        try testQuestUsbDeviceParsing()
        try testQuestUsbReverseParsing()
        try testQuestUsbAdbCandidatePaths()
        try testServerConfigTransportRoundTrip()
        try testRuntimeActivityParsing()
        try testMacWifiParsing()
        try testAdbStatusDisplay()
        print("Companion launcher tests passed")
    }

    private static func testBundleInspection() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let appURL = root.appendingPathComponent("Godot Test.app", isDirectory: true)
        try makeAppBundle(
            at: appURL,
            bundleIdentifier: "org.godotengine.godot",
            bundleName: "Godot Test",
            executableName: "Godot"
        )

        let app = LauncherAppInspector.inspectApp(at: appURL, source: .automatic, allowUnknown: false)
        try expect(app?.kind == .godot, "Expected Godot bundle to be recognized")
        try expect(app?.name == "Godot Test", "Expected bundle display name")
        try expect(app?.executablePath.hasSuffix("Contents/MacOS/Godot") == true, "Expected executable path")
    }

    private static func testLauncherMergeDeduplicatesManualApps() throws {
        let automatic = LauncherApp(
            name: "Godot",
            bundleIdentifier: "org.godotengine.godot",
            bundlePath: "/Applications/Godot.app",
            executablePath: "/Applications/Godot.app/Contents/MacOS/Godot",
            kind: .godot,
            source: .automatic,
            lastSeen: Date()
        )
        let manual = LauncherApp(
            name: "Godot Custom",
            bundleIdentifier: "org.godotengine.godot",
            bundlePath: "/Applications/Godot.app",
            executablePath: "/Applications/Godot.app/Contents/MacOS/Godot",
            kind: .godot,
            source: .manual,
            lastSeen: Date()
        )
        let hidden = LauncherApp(
            name: "Unity",
            bundleIdentifier: "com.unity3d.UnityEditor5.x",
            bundlePath: "/Applications/Unity/Hub/Editor/6000.0.0f1/Unity.app",
            executablePath: "/Applications/Unity/Hub/Editor/6000.0.0f1/Unity.app/Contents/MacOS/Unity",
            kind: .unity,
            source: .automatic,
            lastSeen: Date()
        )
        let store = LauncherAppsStore(
            manualApps: [manual],
            hiddenAutomaticAppPaths: [hidden.bundlePath]
        )

        let merged = LauncherAppPersistence.merge(automaticApps: [automatic, hidden], store: store)
        try expect(merged.count == 1, "Expected hidden auto app to be removed and duplicate to collapse")
        try expect(merged.first?.name == "Godot Custom", "Expected manual app to win over detected app")
        try expect(merged.first?.source == .manual, "Expected merged app to stay manual")
    }

    private static func testRuntimeManifestGeneration() throws {
        let json = CompanionRuntimeInstaller.runtimeManifestJSON(libraryPath: "/tmp/OpenXR Runtime/libopenxr_osx.dylib")
        let data = Data(json.utf8)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let runtime = object?["runtime"] as? [String: Any]
        try expect(runtime?["library_path"] as? String == "/tmp/OpenXR Runtime/libopenxr_osx.dylib", "Expected absolute library path")
        try expect(object?["file_format_version"] as? String == "1.0.0", "Expected OpenXR manifest format version")
    }

    private static func testTerminalScriptQuoting() throws {
        let app = LauncherApp(
            name: "Quoted App",
            bundleIdentifier: nil,
            bundlePath: "/Applications/Quoted App.app",
            executablePath: "/Applications/Quoted App.app/Contents/MacOS/it'works",
            kind: .custom,
            source: .manual,
            lastSeen: Date()
        )
        let script = TerminalLaunchScriptBuilder.script(
            app: app,
            runtimeManifestPath: "/tmp/Runtime's/openxr_osx.json"
        )
        try expect(script.contains("export XR_RUNTIME_JSON='/tmp/Runtime'\\''s/openxr_osx.json'"), "Expected quoted runtime path")
        try expect(script.contains("exec '/Applications/Quoted App.app/Contents/MacOS/it'\\''works'"), "Expected quoted executable path")
    }

    private static func testQuestUsbDeviceParsing() throws {
        let devices = QuestUsbBridge.parseDevices("""
        List of devices attached
        1WMHH000000000 device usb:336592896X product:hollywood model:Quest_3 device:eureka transport_id:4
        ABC unauthorized usb:1-1 transport_id:5
        """)

        try expect(devices.count == 2, "Expected two parsed adb devices")
        try expect(devices[0].serial == "1WMHH000000000", "Expected serial")
        try expect(devices[0].isUsable, "Expected device state to be usable")
        try expect(!devices[1].isUsable, "Expected unauthorized state to be unusable")
    }

    private static func testQuestUsbReverseParsing() throws {
        let ports = QuestUsbBridge.parseReversePorts("""
        UsbFfs tcp:55504 tcp:55504
        UsbFfs tcp:9944 tcp:9944
        UsbFfs tcp:9945 tcp:9945
        UsbFfs tcp:9946 tcp:9946
        """)

        try expect(ports == Set([9944, 9945, 9946]), "Expected configured USB reverse ports")
    }

    private static func testQuestUsbAdbCandidatePaths() throws {
        let candidates = QuestUsbBridge.adbCandidatePaths(
            environment: [
                "ANDROID_HOME": "/tmp/android-home",
                "ANDROID_SDK_ROOT": "/tmp/android-root",
                "PATH": "/custom/bin:/usr/bin",
            ],
            homeDirectory: "/Users/tester"
        )

        try expect(candidates.contains("/tmp/android-home/platform-tools/adb"), "Expected ANDROID_HOME adb path")
        try expect(candidates.contains("/tmp/android-root/platform-tools/adb"), "Expected ANDROID_SDK_ROOT adb path")
        try expect(candidates.contains("/Users/tester/Library/Android/sdk/platform-tools/adb"), "Expected default Android SDK adb path")
        try expect(candidates.contains("/opt/homebrew/bin/adb"), "Expected Homebrew adb path")
        try expect(candidates.contains("/custom/bin/adb"), "Expected PATH adb path")
    }

    private static func testServerConfigTransportRoundTrip() throws {
        let parsed = OpenXRServerConfig.parse(from: """
        [streaming]
        transport = "usb_adb"
        """)
        try expect(parsed.transport == .usbAdb, "Expected USB ADB transport parse")

        let merged = parsed.merged(into: OpenXRServerConfig.defaultText)
        try expect(merged.contains("transport = \"usb_adb\""), "Expected USB ADB transport serialization")
    }

    private static func testRuntimeActivityParsing() throws {
        let status = CompanionRuntimeActivity.parse(Data("""
        {
          "state": "streaming",
          "transport": "usb_adb",
          "device_type": "quest",
          "client_name": "Quest",
          "application_name": "Unity",
          "process_id": 42,
          "updated_at_unix_ms": 1800000000000
        }
        """.utf8))

        try expect(status?.state == .streaming, "Expected streaming state")
        try expect(status?.transport == .usbAdb, "Expected USB ADB transport")
        try expect(status?.deviceType == .quest, "Expected Quest device type")
        try expect(status?.stateDisplayName == "Streaming (USB)", "Expected USB display state")
        try expect(status?.deviceDisplayName == "Quest", "Expected Quest display name")
        try expect(status?.applicationName == "Unity", "Expected application name")
    }

    private static func testMacWifiParsing() throws {
        let device = MacWifiBridge.wifiDevice(from: """
        Hardware Port: Ethernet
        Device: en3

        Hardware Port: Wi-Fi
        Device: en0
        Ethernet Address: aa:bb:cc:dd:ee:ff
        """)
        try expect(device == "en0", "Expected WiFi device parsing")
        try expect(MacWifiBridge.parsePowerOutput("Wi-Fi Power (en0): On") == true, "Expected WiFi on parsing")
        try expect(MacWifiBridge.parsePowerOutput("Wi-Fi Power (en0): Off") == false, "Expected WiFi off parsing")
    }

    private static func testAdbStatusDisplay() throws {
        try expect(!CompanionAdbStatus.missing.isAvailable, "Expected missing ADB to be unavailable")
        try expect(
            CompanionAdbStatus.available(at: "/opt/homebrew/bin/adb").isAvailable,
            "Expected detected ADB to be available"
        )
        try expect(
            CompanionAdbInstallGuidance.message.contains("brew install adb-enhanced"),
            "Expected Homebrew install guidance"
        )
    }

    private static func makeAppBundle(
        at appURL: URL,
        bundleIdentifier: String,
        bundleName: String,
        executableName: String
    ) throws {
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let macOSURL = contentsURL.appendingPathComponent("MacOS", isDirectory: true)
        try FileManager.default.createDirectory(at: macOSURL, withIntermediateDirectories: true)

        let info: [String: Any] = [
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundleName": bundleName,
            "CFBundleExecutable": executableName,
        ]
        let infoData = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try infoData.write(to: contentsURL.appendingPathComponent("Info.plist"))

        let executableURL = macOSURL.appendingPathComponent(executableName)
        try Data("#!/bin/zsh\n".utf8).write(to: executableURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)
    }

    private static func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("openxr-companion-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() {
            throw CompanionLauncherTestFailure(description: message)
        }
    }
}
