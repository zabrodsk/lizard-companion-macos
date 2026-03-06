import AppKit
import SwiftUI

struct CompanionPanelView: View {
    @ObservedObject var engine: CompanionEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(nsImage: engine.menuBarImage)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tom Lizard Companion")
                        .font(.headline)
                    Text("Mood: \(engine.uiState.mood.title)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text("\(engine.uiState.statusSubtitle)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Time working: \(formatDuration(engine.uiState.workDuration))")
                .font(.system(.body, design: .monospaced))

            GroupBox("Animations") {
                HStack {
                    Button("Music") { engine.handleManualTrigger(.musicPlaying) }
                    Button("Sleep") { engine.handleManualTrigger(.idle) }
                    Button("Code") { engine.handleManualTrigger(.typing) }
                    Button("Meeting") { engine.handleManualTrigger(.meetingSoon) }
                }
                .buttonStyle(.borderless)
                Text("Catalog includes: focus, notify, compile, celebrate, break, charge, urgent meeting")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            GroupBox("Settings") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("React to music", isOn: Binding(
                        get: { engine.uiState.toggles.reactToMusic },
                        set: { engine.setReactToMusic($0) }
                    ))

                    Toggle("React to apps", isOn: Binding(
                        get: { engine.uiState.toggles.reactToApps },
                        set: { engine.setReactToApps($0) }
                    ))

                    Toggle("React to activity", isOn: Binding(
                        get: { engine.uiState.toggles.reactToActivity },
                        set: { engine.setReactToActivity($0) }
                    ))

                    Toggle("React to calendar reminders", isOn: Binding(
                        get: { engine.uiState.toggles.reactToCalendar },
                        set: { engine.setReactToCalendar($0) }
                    ))

                    Toggle("Track websites in browsers", isOn: Binding(
                        get: { engine.uiState.toggles.trackBrowserWebsites },
                        set: { engine.setTrackBrowserWebsites($0) }
                    ))

                    Toggle("Subtle transitions", isOn: Binding(
                        get: { engine.uiState.toggles.subtleMode },
                        set: { engine.setSubtleMode($0) }
                    ))

                    PermissionRow(
                        title: "Spotify Access",
                        status: engine.uiState.permissionStatuses.spotify,
                        actionTitle: "Enable",
                        onAction: { engine.requestSpotifyPermission() }
                    )

                    PermissionRow(
                        title: "Calendar Access",
                        status: engine.uiState.permissionStatuses.calendar,
                        actionTitle: "Enable",
                        onAction: { engine.requestCalendarPermission() }
                    )

                    PermissionRow(
                        title: "Browser Website Access",
                        status: engine.uiState.permissionStatuses.browserWebsites,
                        actionTitle: "Enable",
                        onAction: { engine.requestBrowserWebsitePermission() }
                    )
                }
            }

            Divider()

            HStack {
                Button("Open Dashboard") {
                    engine.openDashboard()
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(12)
        .frame(minWidth: 320)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let total = Int(duration)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02dh %02dm %02ds", h, m, s)
    }
}

private struct PermissionRow: View {
    let title: String
    let status: PermissionStatus
    let actionTitle: String
    let onAction: () -> Void

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(status.rawValue.capitalized)
                .foregroundStyle(color(for: status))
                .font(.caption)
            Button(actionTitle, action: onAction)
        }
        .font(.caption)
    }

    private func color(for status: PermissionStatus) -> Color {
        switch status {
        case .authorized:
            return .green
        case .denied:
            return .red
        case .unknown:
            return .orange
        case .unavailable:
            return .secondary
        }
    }
}
