// SPDX-License-Identifier: MPL-2.0

// OpenXR_SimulatorApp.swift — App entry point with window configuration.

import SwiftUI

@main
struct OpenXR_SimulatorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .defaultSize(width: 1280, height: 720)
        #endif
    }
}
