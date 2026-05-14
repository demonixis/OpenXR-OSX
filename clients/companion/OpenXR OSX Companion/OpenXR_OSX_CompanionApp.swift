// SPDX-License-Identifier: MPL-2.0

//
//  OpenXR_OSX_CompanionApp.swift
//  OpenXR OSX Companion
//
//  Created by Yannick Comte on 19/03/2026.
//

import SwiftUI

@main
struct OpenXR_OSX_CompanionApp: App {
    @StateObject private var model = CompanionAppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
    }
}
