import AppKit
import SwiftUI

@main
struct Menu_bar_Companion_appApp: App {
    @StateObject private var engine = CompanionEngine()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanelScene(engine: engine)
        } label: {
            Image(nsImage: engine.menuBarImage)
                .interpolation(.none)
        }
        .menuBarExtraStyle(.window)

        WindowGroup("Dashboard", id: "dashboard") {
            DashboardView(engine: engine)
        }

        Settings {
            SettingsView(engine: engine)
        }
    }
}

private struct MenuBarPanelScene: View {
    @ObservedObject var engine: CompanionEngine
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        CompanionPanelView(engine: engine)
            .onAppear {
                engine.setDashboardOpener {
                    openWindow(id: "dashboard")
                }
            }
    }
}
