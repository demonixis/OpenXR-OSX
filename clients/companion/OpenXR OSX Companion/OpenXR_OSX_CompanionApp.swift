// SPDX-License-Identifier: MPL-2.0

//
//  OpenXR_OSX_CompanionApp.swift
//  OpenXR OSX Companion
//
//  Created by Yannick Comte on 19/03/2026.
//

import SwiftUI
import OpenXRSimulator

@main
struct OpenXR_OSX_CompanionApp: App {
    @StateObject private var model = CompanionAppModel()
    @StateObject private var preferences = CompanionPreferences()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model, preferences: preferences)
        }

        Window("OpenXR Simulator", id: CompanionWindowID.simulator) {
            OpenXRSimulatorView()
        }
        .defaultSize(width: 1280, height: 720)
    }
}
