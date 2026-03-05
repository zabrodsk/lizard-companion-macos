import SwiftUI
import Charts

struct DashboardView: View {
    @ObservedObject var engine: CompanionEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if engine.dashboardState.totalSeconds <= 0 {
                ContentUnavailableView(
                    "No Usage Yet",
                    systemImage: "clock.badge.questionmark",
                    description: Text("Open apps and keep working. Tom will start tracking your frontmost app time automatically.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                kpis
                categoryChart
                appList
            }

            Spacer(minLength: 0)

            HStack {
                Button("Open Settings") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                Spacer()
                Button("Reset Usage Data", role: .destructive) {
                    engine.resetUsageData()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(18)
        .frame(minWidth: 760, minHeight: 560)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Companion Dashboard")
                    .font(.title2.weight(.semibold))
                Text("Tracked frontmost app time")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Range", selection: Binding(
                get: { engine.dashboardState.selectedRange },
                set: { engine.setDashboardRange($0) }
            )) {
                Text("Today").tag(DashboardRange.today)
                Text("Last 7 Days").tag(DashboardRange.last7Days)
            }
            .pickerStyle(.segmented)
            .frame(width: 240)
        }
    }

    private var kpis: some View {
        let topApp = engine.dashboardState.appEntries.first
        let topCategory = engine.dashboardState.categoryEntries.first

        return HStack(spacing: 12) {
            DashboardMetricCard(title: "Total Tracked", value: formatDuration(engine.dashboardState.totalSeconds))
            DashboardMetricCard(title: "Top App", value: topApp?.appName ?? "-")
            DashboardMetricCard(title: "Top Category", value: topCategory.map(categoryTitle) ?? "-")
        }
    }

    private var categoryChart: some View {
        GroupBox("By Category") {
            Chart(engine.dashboardState.categoryEntries) { entry in
                BarMark(
                    x: .value("Time", entry.seconds),
                    y: .value("Category", categoryTitle(entry))
                )
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let seconds = value.as(Double.self) {
                            Text(shortDuration(seconds))
                        }
                    }
                }
            }
            .frame(height: 220)
        }
    }

    private var appList: some View {
        GroupBox("By App") {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(engine.dashboardState.appEntries) { entry in
                        HStack(spacing: 10) {
                            Image(nsImage: appIcon(for: entry.bundleID))
                                .resizable()
                                .frame(width: 18, height: 18)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            Text(entry.appName)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(categoryTitle(entry.category))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatDuration(entry.seconds))
                                .font(.system(.body, design: .monospaced))
                        }
                        Divider()
                    }
                }
            }
            .frame(maxHeight: 220)
        }
    }

    private func appIcon(for bundleID: String) -> NSImage {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
        }
        let image = NSWorkspace.shared.icon(forFile: appURL.path)
        image.size = NSSize(width: 18, height: 18)
        return image
    }

    private func categoryTitle(_ entry: CategoryUsageEntry) -> String {
        categoryTitle(entry.category)
    }

    private func categoryTitle(_ category: AppGroup) -> String {
        switch category {
        case .coding: return "Coding"
        case .browser: return "Browser"
        case .chat: return "Chat"
        case .music: return "Music"
        case .ai: return "AI"
        case .meeting: return "Meetings"
        case .productivity: return "Productivity"
        case .launcher: return "Launcher"
        case .racing: return "Racing"
        case .security: return "Security"
        case .other: return "Other"
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let total = Int(duration)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02dh %02dm %02ds", h, m, s)
    }

    private func shortDuration(_ duration: TimeInterval) -> String {
        let total = Int(duration)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m)m"
    }
}

private struct DashboardMetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }
}
