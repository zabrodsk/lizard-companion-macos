import SwiftUI

struct SettingsView: View {
    @ObservedObject var engine: CompanionEngine
    @AppStorage(CompanionDefaults.batteryThresholdKey) private var batteryThreshold = CompanionDefaults.batteryThresholdDefault
    @AppStorage(CompanionDefaults.meetingLeadMinutesKey) private var meetingLeadMinutes = CompanionDefaults.meetingLeadMinutesDefault

    var body: some View {
        Form {
            Section("Behavior") {
                Stepper("Low battery threshold: \(batteryThreshold)%", value: $batteryThreshold, in: 5...50)
                    .onChange(of: batteryThreshold) { _, value in
                        engine.setBatteryThreshold(value)
                    }

                Stepper("Meeting reminder window: \(meetingLeadMinutes) min", value: $meetingLeadMinutes, in: 1...30)
                    .onChange(of: meetingLeadMinutes) { _, value in
                        engine.setMeetingLeadMinutes(value)
                    }
            }

            Section("Permissions") {
                HStack {
                    Text("Spotify")
                    Spacer()
                    Text(engine.uiState.permissionStatuses.spotify.rawValue.capitalized)
                    Button("Enable") { engine.requestSpotifyPermission() }
                }
                HStack {
                    Text("Calendar")
                    Spacer()
                    Text(engine.uiState.permissionStatuses.calendar.rawValue.capitalized)
                    Button("Enable") { engine.requestCalendarPermission() }
                }
            }
        }
        .padding()
        .frame(width: 420, height: 220)
        .onAppear {
            engine.setBatteryThreshold(batteryThreshold)
            engine.setMeetingLeadMinutes(meetingLeadMinutes)
        }
    }
}
