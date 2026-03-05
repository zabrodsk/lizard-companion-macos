import AppKit
import SwiftUI

struct MenuBarRoot: View {
    @StateObject private var engine = CompanionEngine()

    var body: some View {
        CompanionPanelView(engine: engine)
    }

    var iconImage: NSImage {
        engine.menuBarImage
    }

    var settingsView: some View {
        SettingsView(engine: engine)
    }
}
