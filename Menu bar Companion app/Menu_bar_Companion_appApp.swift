import AppKit
import SwiftUI

@main
struct Menu_bar_Companion_appApp: App {
    @StateObject private var engine = CompanionEngine()

    var body: some Scene {
        MenuBarExtra {
            CompanionPanelView(engine: engine)
        } label: {
            Image(nsImage: engine.menuBarImage)
                .interpolation(.none)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(engine: engine)
        }
    }
}
