// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct ContentView: View {
    @ObservedObject var model: CompanionAppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                runtimeSection
                configSection
            }
            .padding(20)
        }
        .frame(minWidth: 760, minHeight: 620)
        .alert("Error", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { newValue in
                if !newValue {
                    model.errorMessage = nil
                }
            })
        ) {
            Button("OK", role: .cancel) {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OpenXR OSX Companion")
                .font(.largeTitle)
                .fontWeight(.semibold)
            Text("Configure the runtime and register or unregister the OpenXR JSON from a standard macOS app window.")
                .foregroundStyle(.secondary)

            if !model.statusMessage.isEmpty {
                Text(model.statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
        }
    }

    private var runtimeSection: some View {
        GroupBox("Runtime Registration") {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    TextField("Path to openxr runtime json", text: $model.runtimeManifestPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse") {
                        model.chooseRuntimeManifest()
                    }
                    Button("Reveal") {
                        revealInFinder(model.runtimeManifestPath)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Registration file", value: model.activeRuntimePath)
                    LabeledContent("Current target", value: model.runtimeStatus.activeRuntimeTarget ?? "Not registered")
                    LabeledContent("Selected target active", value: model.isSelectedRuntimeRegistered ? "Yes" : "No")
                }

                HStack {
                    Button("Refresh") {
                        model.refreshRuntimeStatus()
                    }
                    Spacer()
                    Button(model.registrationButtonTitle) {
                        model.toggleRuntimeRegistration()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.top, 8)
        }
    }

    private var configSection: some View {
        GroupBox("Runtime Configuration") {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Runtime enabled", isOn: $model.serverConfig.runtimeEnabled)
                Toggle("Write server log file", isOn: $model.serverConfig.fileLogging)
                Toggle("Capture Quest logcat", isOn: $model.serverConfig.questLogcat)

                LabeledSlider(
                    title: "Bitrate",
                    value: Binding(
                        get: { Double(model.serverConfig.bitrateMbps) },
                        set: { model.serverConfig.bitrateMbps = Int($0.rounded()) }
                    ),
                    range: 1...200,
                    displayValue: "\(model.serverConfig.bitrateMbps) Mbps"
                )

                LabeledSlider(
                    title: "Vertical FOV",
                    value: Binding(
                        get: { Double(model.serverConfig.fovDegrees) },
                        set: { model.serverConfig.fovDegrees = Int($0.rounded()) }
                    ),
                    range: 60...150,
                    displayValue: "\(model.serverConfig.fovDegrees) degrees"
                )

                LabeledSlider(
                    title: "Resolution Scale",
                    value: $model.serverConfig.resolutionScale,
                    range: 0.25...1.0,
                    displayValue: String(format: "%.2f", model.serverConfig.resolutionScale)
                )

                LabeledSlider(
                    title: "Keyframe Interval",
                    value: Binding(
                        get: { Double(model.serverConfig.keyframeIntervalSec) },
                        set: { model.serverConfig.keyframeIntervalSec = Int($0.rounded()) }
                    ),
                    range: 1...10,
                    displayValue: "\(model.serverConfig.keyframeIntervalSec) s"
                )

                Picker("Encoder preset", selection: $model.serverConfig.encoderPreset) {
                    ForEach(EncoderPreset.allCases) { preset in
                        Text(preset.rawValue.capitalized).tag(preset)
                    }
                }

                HStack {
                    Button("Save Configuration") {
                        model.saveStructuredConfig()
                    }
                    Button("Reload From Disk") {
                        model.resetToDisk()
                    }
                    Spacer()
                    Button("Reveal Config") {
                        revealInFinder(model.configFilePath)
                    }
                }
            }
            .padding(.top, 8)
        }
    }
}

private struct LabeledSlider<Value: BinaryFloatingPoint>: View where Value.Stride: BinaryFloatingPoint {
    let title: String
    @Binding var value: Value
    let range: ClosedRange<Value>
    let displayValue: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(displayValue)
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range)
        }
    }
}

#Preview {
    ContentView(model: CompanionAppModel())
}
