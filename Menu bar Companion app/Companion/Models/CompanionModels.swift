import AppKit
import Combine
import Foundation

enum CompanionMood: String, CaseIterable {
    case sleepy
    case productive
    case excited
    case worried
    case reminding

    var title: String {
        switch self {
        case .sleepy: return "sleepy"
        case .productive: return "productive"
        case .excited: return "excited"
        case .worried: return "worried"
        case .reminding: return "reminding"
        }
    }
}

enum CompanionTrigger: String, CaseIterable {
    case idle
    case typing
    case musicPlaying
    case batteryLow
    case meetingSoon
    case manual
}

enum LoopMode {
    case loop
}

struct AnimationClip {
    let id: String
    let frames: [NSImage]
    let fps: Double
    let loopMode: LoopMode

    init(id: String, frames: [NSImage], fps: Double, loopMode: LoopMode = .loop) {
        self.id = id
        self.frames = frames
        self.fps = max(1, fps)
        self.loopMode = loopMode
    }
}

enum PermissionStatus: String {
    case unknown
    case authorized
    case denied
    case unavailable
}

struct CompanionToggles: Equatable {
    var reactToMusic: Bool
    var reactToApps: Bool
    var reactToActivity: Bool
    var reactToCalendar: Bool
    var subtleMode: Bool
    var trackBrowserWebsites: Bool
}

struct ActivityState {
    var isIdle: Bool
    var lastInputDate: Date
    var intensity: Double
}

enum AppGroup: String, CaseIterable, Codable {
    case coding
    case browser
    case chat
    case music
    case ai
    case meeting
    case productivity
    case launcher
    case racing
    case security
    case other
}

struct AppContext {
    var bundleIdentifier: String?
    var appName: String
    var group: AppGroup
}

enum DashboardRange: String, CaseIterable {
    case today
    case last7Days
}

struct AppUsageEntry: Identifiable, Codable {
    var bundleID: String
    var appName: String
    var category: AppGroup
    var seconds: TimeInterval

    var id: String {
        "\(bundleID)::\(appName)::\(category.rawValue)"
    }
}

struct WebsiteUsageEntry: Identifiable, Codable {
    var browserBundleID: String
    var browserAppName: String
    var domain: String
    var seconds: TimeInterval

    var id: String {
        "\(browserBundleID)::\(domain)"
    }
}

struct CategoryUsageEntry: Identifiable, Codable {
    var category: AppGroup
    var seconds: TimeInterval

    var id: String {
        category.rawValue
    }
}

struct DayUsageSnapshot: Identifiable, Codable {
    var dateKey: String
    var appEntries: [AppUsageEntry]
    var categoryEntries: [CategoryUsageEntry]
    var websiteEntries: [WebsiteUsageEntry]
    var totalSeconds: TimeInterval

    var id: String {
        dateKey
    }
}

struct UsageDashboardState {
    var selectedRange: DashboardRange
    var days: [DayUsageSnapshot]
    var appEntries: [AppUsageEntry]
    var categoryEntries: [CategoryUsageEntry]
    var websiteEntries: [WebsiteUsageEntry]
    var totalSeconds: TimeInterval
}

protocol UsageStore {
    func load() -> [DayUsageSnapshot]
    func save(_ snapshots: [DayUsageSnapshot])
}

struct BatteryState {
    var level: Int
    var isCharging: Bool
    var isLowBattery: Bool
}

struct MusicState {
    var isSpotifyInstalled: Bool
    var isPlaying: Bool
    var permissionStatus: PermissionStatus
}

struct CalendarState {
    var permissionStatus: PermissionStatus
    var meetingSoon: Bool
    var nextMeetingDate: Date?
}

struct BrowserSiteState {
    var bundleID: String?
    var appName: String
    var domain: String?
    var permissionStatus: PermissionStatus
    var isSupported: Bool
}

struct CompanionPermissionStatuses {
    var spotify: PermissionStatus
    var calendar: PermissionStatus
    var browserWebsites: PermissionStatus
}

struct CompanionUIState {
    var mood: CompanionMood
    var activeClipID: String
    var workDuration: TimeInterval
    var permissionStatuses: CompanionPermissionStatuses
    var toggles: CompanionToggles
    var statusSubtitle: String
    var batteryState: BatteryState
}

struct CompanionState {
    var activeMood: CompanionMood
    var activeTrigger: CompanionTrigger
    var elapsedWorkTime: TimeInterval
    var permissions: CompanionPermissionStatuses
    var toggles: CompanionToggles
}

enum SignalEvent {
    case activity(ActivityState)
    case frontmostApp(AppContext)
    case battery(BatteryState)
    case spotify(MusicState)
    case calendar(CalendarState)
    case browserSite(BrowserSiteState)
}

protocol SignalService {
    var publisher: AnyPublisher<SignalEvent, Never> { get }
    func start()
    func stop()
}

enum CompanionDefaults {
    static let batteryThresholdKey = "companion.batteryThreshold"
    static let meetingLeadMinutesKey = "companion.meetingLeadMinutes"
    static let reactToMusicKey = "companion.reactToMusic"
    static let reactToAppsKey = "companion.reactToApps"
    static let reactToActivityKey = "companion.reactToActivity"
    static let reactToCalendarKey = "companion.reactToCalendar"
    static let subtleModeKey = "companion.subtleMode"
    static let trackBrowserWebsitesKey = "companion.trackBrowserWebsites"

    static let batteryThresholdDefault = 20
    static let meetingLeadMinutesDefault = 5

    static let defaultToggles = CompanionToggles(
        reactToMusic: false,
        reactToApps: true,
        reactToActivity: true,
        reactToCalendar: false,
        subtleMode: true,
        trackBrowserWebsites: false
    )
}
