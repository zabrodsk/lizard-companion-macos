import AppKit
import Combine
import Foundation

@MainActor
final class CompanionEngine: ObservableObject {
    @Published private(set) var uiState: CompanionUIState
    @Published private(set) var menuBarImage: NSImage
    @Published private(set) var dashboardState: UsageDashboardState

    private let activityService: ActivityMonitorService
    private let appService: ActiveAppService
    private let batteryService: BatteryService
    private let spotifyService: SpotifyService
    private let calendarService: CalendarService
    private let browserWebsiteService: BrowserWebsiteService
    private let usageTracker: UsageTrackerService
    private let animator: SpriteAnimator

    private let clips: [String: AnimationClip]
    private var cancellables = Set<AnyCancellable>()
    private var sessionStartDate = Date()
    private var workTimer: Timer?

    private var lastActivityState = ActivityState(isIdle: false, lastInputDate: Date(), intensity: 1)
    private var lastAppContext = AppContext(bundleIdentifier: nil, appName: "Unknown", group: .other)
    private var lastBatteryState = BatteryState(level: 100, isCharging: true, isLowBattery: false)
    private var lastMusicState = MusicState(isSpotifyInstalled: false, isPlaying: false, permissionStatus: .unknown)
    private var lastCalendarState = CalendarState(permissionStatus: .unknown, meetingSoon: false, nextMeetingDate: nil)
    private var lastBrowserSiteState = BrowserSiteState(bundleID: nil, appName: "Unknown", domain: nil, permissionStatus: .unknown, isSupported: false)
    private var manualTrigger: CompanionTrigger?
    private var dashboardOpener: (() -> Void)?

    private var batteryThreshold: Int {
        get { UserDefaults.standard.object(forKey: CompanionDefaults.batteryThresholdKey) as? Int ?? CompanionDefaults.batteryThresholdDefault }
        set {
            UserDefaults.standard.set(newValue, forKey: CompanionDefaults.batteryThresholdKey)
            batteryService.lowBatteryThreshold = newValue
            evaluateState()
        }
    }

    private var meetingLeadMinutes: Int {
        get { UserDefaults.standard.object(forKey: CompanionDefaults.meetingLeadMinutesKey) as? Int ?? CompanionDefaults.meetingLeadMinutesDefault }
        set {
            UserDefaults.standard.set(newValue, forKey: CompanionDefaults.meetingLeadMinutesKey)
            calendarService.leadMinutes = newValue
            evaluateState()
        }
    }

    init(
        activityService: ActivityMonitorService? = nil,
        appService: ActiveAppService? = nil,
        batteryService: BatteryService? = nil,
        spotifyService: SpotifyService? = nil,
        calendarService: CalendarService? = nil,
        browserWebsiteService: BrowserWebsiteService? = nil,
        usageTracker: UsageTrackerService? = nil
    ) {
        self.activityService = activityService ?? ActivityMonitorService()
        self.appService = appService ?? ActiveAppService()
        self.batteryService = batteryService ?? BatteryService()
        self.spotifyService = spotifyService ?? SpotifyService()
        self.calendarService = calendarService ?? CalendarService()
        self.browserWebsiteService = browserWebsiteService ?? BrowserWebsiteService()
        self.usageTracker = usageTracker ?? UsageTrackerService()

        let clipSet = CompanionSpriteCatalog.clips()
        self.clips = clipSet
        let initialClip = clipSet["idle_blink"] ?? AnimationClip(id: "fallback", frames: [CompanionSpriteCatalog.fallbackIcon()], fps: 1)
        self.animator = SpriteAnimator(initialClip: initialClip)
        self.menuBarImage = initialClip.frames.first ?? CompanionSpriteCatalog.fallbackIcon()

        let toggles = Self.loadToggles()
        let permissions = CompanionPermissionStatuses(spotify: .unknown, calendar: .unknown, browserWebsites: .unknown)
        self.uiState = CompanionUIState(
            mood: .productive,
            activeClipID: initialClip.id,
            workDuration: 0,
            permissionStatuses: permissions,
            toggles: toggles,
            statusSubtitle: "Ambient mode",
            batteryState: BatteryState(level: 100, isCharging: true, isLowBattery: false)
        )
        self.dashboardState = self.usageTracker.currentDashboardState()

        self.batteryService.lowBatteryThreshold = batteryThreshold
        self.calendarService.leadMinutes = meetingLeadMinutes
        self.spotifyService.enabled = toggles.reactToMusic
        self.calendarService.enabled = toggles.reactToCalendar
        self.browserWebsiteService.enabled = toggles.trackBrowserWebsites

        bindServices()
        bindAnimator()
        bindUsageTracker()
        start()
    }

    func setReactToMusic(_ enabled: Bool) {
        uiState.toggles.reactToMusic = enabled
        spotifyService.enabled = enabled
        persistToggles()
        if enabled, uiState.permissionStatuses.spotify == .unknown {
            spotifyService.requestPermission()
        }
        evaluateState()
    }

    func setReactToApps(_ enabled: Bool) {
        uiState.toggles.reactToApps = enabled
        persistToggles()
        evaluateState()
    }

    func setReactToActivity(_ enabled: Bool) {
        uiState.toggles.reactToActivity = enabled
        persistToggles()
        evaluateState()
    }

    func setReactToCalendar(_ enabled: Bool) {
        uiState.toggles.reactToCalendar = enabled
        calendarService.enabled = enabled
        persistToggles()
        if enabled, uiState.permissionStatuses.calendar == .unknown {
            calendarService.requestPermission()
        }
        evaluateState()
    }

    func setSubtleMode(_ enabled: Bool) {
        uiState.toggles.subtleMode = enabled
        persistToggles()
    }

    func setTrackBrowserWebsites(_ enabled: Bool) {
        uiState.toggles.trackBrowserWebsites = enabled
        browserWebsiteService.enabled = enabled
        persistToggles()
        if enabled, uiState.permissionStatuses.browserWebsites == .unknown {
            browserWebsiteService.requestPermission()
        } else if enabled == false {
            usageTracker.setCurrentDomain(nil)
        }
        evaluateState()
    }

    func setBatteryThreshold(_ value: Int) {
        batteryThreshold = value
    }

    func setMeetingLeadMinutes(_ value: Int) {
        meetingLeadMinutes = value
    }

    func requestSpotifyPermission() {
        spotifyService.requestPermission()
    }

    func requestCalendarPermission() {
        calendarService.requestPermission()
    }

    func requestBrowserWebsitePermission() {
        browserWebsiteService.requestPermission()
    }

    func handleManualTrigger(_ trigger: CompanionTrigger) {
        manualTrigger = trigger
        evaluateState()

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self else { return }
            self.manualTrigger = nil
            self.evaluateState()
        }
    }

    func setDashboardRange(_ range: DashboardRange) {
        usageTracker.setSelectedRange(range)
        dashboardState = usageTracker.currentDashboardState()
    }

    func setDashboardOpener(_ opener: @escaping () -> Void) {
        dashboardOpener = opener
    }

    func openDashboard() {
        dashboardOpener?()
    }

    func resetUsageData() {
        usageTracker.reset()
        dashboardState = usageTracker.currentDashboardState()
    }

    private func start() {
        activityService.start()
        appService.start()
        batteryService.start()
        spotifyService.start()
        calendarService.start()
        browserWebsiteService.start()
        usageTracker.start()

        workTimer?.invalidate()
        workTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let owner = self else { return }
            Task { @MainActor [owner] in
                owner.uiState.workDuration = Date().timeIntervalSince(owner.sessionStartDate)
                owner.dashboardState = owner.usageTracker.currentDashboardState()
            }
        }
        if let workTimer {
            RunLoop.main.add(workTimer, forMode: .common)
        }
    }

    private func stop() {
        workTimer?.invalidate()
        workTimer = nil
        usageTracker.stop()
        activityService.stop()
        appService.stop()
        batteryService.stop()
        spotifyService.stop()
        calendarService.stop()
        browserWebsiteService.stop()
    }

    private func bindServices() {
        activityService.publisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in self?.handle(event) }
            .store(in: &cancellables)

        appService.publisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in self?.handle(event) }
            .store(in: &cancellables)

        batteryService.publisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in self?.handle(event) }
            .store(in: &cancellables)

        spotifyService.publisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in self?.handle(event) }
            .store(in: &cancellables)

        calendarService.publisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in self?.handle(event) }
            .store(in: &cancellables)

        browserWebsiteService.publisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in self?.handle(event) }
            .store(in: &cancellables)
    }

    private func bindAnimator() {
        animator.$currentImage
            .receive(on: RunLoop.main)
            .sink { [weak self] image in
                self?.menuBarImage = image
            }
            .store(in: &cancellables)
    }

    private func bindUsageTracker() {
        usageTracker.onUsageUpdated = { [weak self] in
            Task { @MainActor in
                guard let strongSelf = self else { return }
                strongSelf.dashboardState = strongSelf.usageTracker.currentDashboardState()
            }
        }
    }

    private func handle(_ event: SignalEvent) {
        switch event {
        case .activity(let activity):
            lastActivityState = activity
        case .frontmostApp(let app):
            lastAppContext = app
            browserWebsiteService.setFrontmostApp(app)
            usageTracker.setCurrentApp(app)
        case .battery(let battery):
            lastBatteryState = battery
            uiState.batteryState = battery
        case .spotify(let music):
            lastMusicState = music
            uiState.permissionStatuses.spotify = music.permissionStatus
        case .calendar(let calendar):
            lastCalendarState = calendar
            uiState.permissionStatuses.calendar = calendar.permissionStatus
        case .browserSite(let site):
            lastBrowserSiteState = site
            uiState.permissionStatuses.browserWebsites = site.permissionStatus
            let trackedDomain = uiState.toggles.trackBrowserWebsites && site.isSupported ? site.domain : nil
            usageTracker.setCurrentDomain(trackedDomain)
        }

        evaluateState()
    }

    private func evaluateState() {
        applyAnimationPowerProfile()

        let trigger = Self.resolveTrigger(
            manualTrigger: manualTrigger,
            toggles: uiState.toggles,
            battery: lastBatteryState,
            calendar: lastCalendarState,
            music: lastMusicState,
            activity: lastActivityState,
            app: lastAppContext
        )

        let mood = Self.mapMood(trigger)
        let clipID = clipID(for: trigger)
        if let clip = clips[clipID] {
            animator.setClip(clip, debounce: uiState.toggles.subtleMode ? 0.8 : 0.35)
            uiState.activeClipID = clip.id
        }

        uiState.mood = mood
        uiState.statusSubtitle = statusSubtitle(trigger: trigger)
    }

    private func applyAnimationPowerProfile() {
        let multiplier: Double
        if uiState.toggles.subtleMode {
            if lastBatteryState.isLowBattery {
                multiplier = 0.25
            } else if !lastBatteryState.isCharging {
                multiplier = 0.45
            } else {
                multiplier = 0.60
            }
        } else {
            if lastBatteryState.isLowBattery {
                multiplier = 0.45
            } else if !lastBatteryState.isCharging {
                multiplier = 0.70
            } else {
                multiplier = 0.85
            }
        }
        animator.setSpeedMultiplier(multiplier)
    }

    static func resolveTrigger(
        manualTrigger: CompanionTrigger?,
        toggles: CompanionToggles,
        battery: BatteryState,
        calendar: CalendarState,
        music: MusicState,
        activity: ActivityState,
        app: AppContext
    ) -> CompanionTrigger {
        if let manualTrigger { return manualTrigger }
        if battery.isLowBattery { return .batteryLow }
        if toggles.reactToCalendar, calendar.meetingSoon { return .meetingSoon }
        if toggles.reactToMusic, music.isPlaying { return .musicPlaying }

        if toggles.reactToApps, app.group == .coding,
           toggles.reactToActivity, !activity.isIdle {
            return .typing
        }

        if toggles.reactToActivity, activity.isIdle {
            return .idle
        }

        return .typing
    }

    static func mapMood(_ trigger: CompanionTrigger) -> CompanionMood {
        switch trigger {
        case .idle:
            return .sleepy
        case .typing:
            return .productive
        case .musicPlaying:
            return .excited
        case .batteryLow:
            return .worried
        case .meetingSoon:
            return .reminding
        case .manual:
            return .excited
        }
    }

    private func clipID(for trigger: CompanionTrigger) -> String {
        switch trigger {
        case .idle:
            return "sleep"
        case .typing:
            guard uiState.toggles.reactToApps else {
                return "focus_deep"
            }
            switch lastAppContext.group {
            case .coding:
                if isGitHubDesktop(lastAppContext.bundleIdentifier) {
                    return "github_sync"
                }
                if lastActivityState.intensity < 0.72 {
                    return "focus_deep"
                }
                if isCursorApp(lastAppContext.bundleIdentifier) {
                    return "code_cursor"
                }
                if isTerminalApp(lastAppContext.bundleIdentifier) {
                    return "code_terminal"
                }
                if isBuildHeavyApp(lastAppContext.bundleIdentifier) {
                    return "compile_wait"
                }
                return "code_mac"
            case .browser:
                return "browse_think"
            case .chat:
                if lastActivityState.intensity < 0.65 {
                    return "focus_deep"
                }
                return "chat_talk"
            case .music:
                return "music_headphones"
            case .ai:
                return "ai_assistant"
            case .meeting:
                return "meeting_call"
            case .productivity:
                if isSpreadsheetApp(lastAppContext.bundleIdentifier) {
                    return "sheet_crunch"
                }
                return "docs_write"
            case .launcher:
                return "launch_fast"
            case .racing:
                return "racing_watch"
            case .security:
                return "secure_shield"
            case .other:
                return "focus_deep"
            }
        case .musicPlaying:
            return "music_headphones"
        case .batteryLow:
            return lastBatteryState.isCharging ? "charge_recover" : "battery_worry"
        case .meetingSoon:
            if let nextMeeting = lastCalendarState.nextMeetingDate,
               nextMeeting.timeIntervalSinceNow <= 120 {
                return "meeting_urgent"
            }
            return "meeting_wave"
        case .manual:
            return "idle_blink"
        }
    }

    private func statusSubtitle(trigger: CompanionTrigger) -> String {
        switch trigger {
        case .idle:
            return "Resting"
        case .typing:
            guard uiState.toggles.reactToApps else {
                return "Focused mode"
            }
            switch lastAppContext.group {
            case .coding:
                if isGitHubDesktop(lastAppContext.bundleIdentifier) {
                    return "Syncing with GitHub Desktop"
                }
                if isCursorApp(lastAppContext.bundleIdentifier) {
                    return "Coding in Cursor"
                }
                if isTerminalApp(lastAppContext.bundleIdentifier) {
                    return "Hacking in Terminal"
                }
                if isBuildHeavyApp(lastAppContext.bundleIdentifier) {
                    return "Build mode in \(lastAppContext.appName)"
                }
                return "Coding in \(lastAppContext.appName)"
            case .browser:
                return "Research mode in \(lastAppContext.appName)"
            case .chat:
                return "Chatting in \(lastAppContext.appName)"
            case .music:
                return "Listening in \(lastAppContext.appName)"
            case .ai:
                return "Thinking with \(lastAppContext.appName)"
            case .meeting:
                return "In meetings via \(lastAppContext.appName)"
            case .productivity:
                if isSpreadsheetApp(lastAppContext.bundleIdentifier) {
                    return "Crunching numbers in \(lastAppContext.appName)"
                }
                return "Writing in \(lastAppContext.appName)"
            case .launcher:
                return "Launching commands in \(lastAppContext.appName)"
            case .racing:
                return "Race mode in \(lastAppContext.appName)"
            case .security:
                return "Security mode in \(lastAppContext.appName)"
            case .other:
                return "Focused on \(lastAppContext.appName)"
            }
        case .musicPlaying:
            return "Dancing with Spotify"
        case .batteryLow:
            return "Battery \(lastBatteryState.level)%"
        case .meetingSoon:
            if let nextMeeting = lastCalendarState.nextMeetingDate {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .short
                return "Meeting \(formatter.localizedString(for: nextMeeting, relativeTo: Date()))"
            }
            return "Meeting soon"
        case .manual:
            return "Preview mode"
        }
    }

    private func isTerminalApp(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return bundleID == "com.apple.Terminal" || bundleID == "com.googlecode.iterm2" || bundleID == "dev.warp.Warp-Stable"
    }

    private func isCursorApp(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return bundleID == "com.todesktop.230313mzl4w4u92"
    }

    private func isGitHubDesktop(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return bundleID == "com.github.GitHubClient"
    }

    private func isBuildHeavyApp(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return bundleID == "com.apple.dt.Xcode"
    }

    private func isSpreadsheetApp(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return bundleID == "com.microsoft.Excel" || bundleID == "com.apple.iWork.Numbers"
    }

    private func persistToggles() {
        let defaults = UserDefaults.standard
        defaults.set(uiState.toggles.reactToMusic, forKey: CompanionDefaults.reactToMusicKey)
        defaults.set(uiState.toggles.reactToApps, forKey: CompanionDefaults.reactToAppsKey)
        defaults.set(uiState.toggles.reactToActivity, forKey: CompanionDefaults.reactToActivityKey)
        defaults.set(uiState.toggles.reactToCalendar, forKey: CompanionDefaults.reactToCalendarKey)
        defaults.set(uiState.toggles.subtleMode, forKey: CompanionDefaults.subtleModeKey)
        defaults.set(uiState.toggles.trackBrowserWebsites, forKey: CompanionDefaults.trackBrowserWebsitesKey)
    }

    private static func loadToggles() -> CompanionToggles {
        let defaults = UserDefaults.standard
        let preset = CompanionDefaults.defaultToggles

        func bool(for key: String, fallback: Bool) -> Bool {
            if defaults.object(forKey: key) == nil {
                return fallback
            }
            return defaults.bool(forKey: key)
        }

        return CompanionToggles(
            reactToMusic: bool(for: CompanionDefaults.reactToMusicKey, fallback: preset.reactToMusic),
            reactToApps: bool(for: CompanionDefaults.reactToAppsKey, fallback: preset.reactToApps),
            reactToActivity: bool(for: CompanionDefaults.reactToActivityKey, fallback: preset.reactToActivity),
            reactToCalendar: bool(for: CompanionDefaults.reactToCalendarKey, fallback: preset.reactToCalendar),
            subtleMode: bool(for: CompanionDefaults.subtleModeKey, fallback: preset.subtleMode),
            trackBrowserWebsites: bool(for: CompanionDefaults.trackBrowserWebsitesKey, fallback: preset.trackBrowserWebsites)
        )
    }
}
