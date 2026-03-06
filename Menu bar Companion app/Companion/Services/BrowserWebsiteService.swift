import AppKit
import Combine
import Foundation

final class BrowserWebsiteService: SignalService {
    private enum SupportedBrowser: String, CaseIterable {
        case safari = "com.apple.Safari"
        case comet = "ai.perplexity.comet"
        case cometLegacy = "ai.perplexity.mac"

        var appName: String {
            switch self {
            case .safari:
                return "Safari"
            case .comet, .cometLegacy:
                return "Comet"
            }
        }

        var scriptingTarget: String {
            switch self {
            case .safari:
                return "application id \"com.apple.Safari\""
            case .comet:
                return "application id \"ai.perplexity.comet\""
            case .cometLegacy:
                return "application id \"ai.perplexity.mac\""
            }
        }

        var isInstalled: Bool {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: rawValue) != nil
        }
    }

    var publisher: AnyPublisher<SignalEvent, Never> {
        subject.eraseToAnyPublisher()
    }

    private let subject = PassthroughSubject<SignalEvent, Never>()
    private var timer: Timer?
    private(set) var permissionStatus: PermissionStatus = .unknown
    var enabled = false
    private var currentAppContext = AppContext(bundleIdentifier: nil, appName: "Unknown", group: .other)

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.emitState()
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
        emitState()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func setFrontmostApp(_ context: AppContext) {
        currentAppContext = context
        emitState()
    }

    func requestPermission() {
        guard let browser = currentSupportedBrowser() ?? SupportedBrowser.allCases.first(where: \.isInstalled) else {
            permissionStatus = .unavailable
            emitState()
            return
        }

        let result = runAppleScript("tell \(browser.scriptingTarget) to name")
        permissionStatus = mapPermission(from: result.error)
        emitState()
    }

    private func emitState() {
        guard enabled else {
            subject.send(.browserSite(BrowserSiteState(
                bundleID: currentAppContext.bundleIdentifier,
                appName: currentAppContext.appName,
                domain: nil,
                permissionStatus: permissionStatus,
                isSupported: isSupportedBrowser(currentAppContext.bundleIdentifier)
            )))
            return
        }

        guard let browser = currentSupportedBrowser() else {
            subject.send(.browserSite(BrowserSiteState(
                bundleID: currentAppContext.bundleIdentifier,
                appName: currentAppContext.appName,
                domain: nil,
                permissionStatus: permissionStatus,
                isSupported: false
            )))
            return
        }

        let probe = runAppleScript(script(for: browser))
        permissionStatus = mapPermission(from: probe.error)
        let domain = normalizeDomain(from: probe.output)
        subject.send(.browserSite(BrowserSiteState(
            bundleID: browser.rawValue,
            appName: browser.appName,
            domain: domain,
            permissionStatus: permissionStatus,
            isSupported: true
        )))
    }

    private func currentSupportedBrowser() -> SupportedBrowser? {
        guard let bundleID = currentAppContext.bundleIdentifier else { return nil }
        return SupportedBrowser(rawValue: bundleID)
    }

    private func isSupportedBrowser(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return SupportedBrowser(rawValue: bundleID) != nil
    }

    private func script(for browser: SupportedBrowser) -> String {
        switch browser {
        case .safari:
            return """
            tell \(browser.scriptingTarget)
                if (count of windows) is 0 then return ""
                try
                    return URL of current tab of front window
                on error
                    return ""
                end try
            end tell
            """
        case .comet, .cometLegacy:
            return """
            tell \(browser.scriptingTarget)
                if (count of windows) is 0 then return ""
                try
                    return URL of active tab of front window
                on error
                    try
                        return URL of current tab of front window
                    on error
                        return ""
                    end try
                end try
            end tell
            """
        }
    }

    private func normalizeDomain(from output: String?) -> String? {
        guard let output else { return nil }
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else { return nil }
        guard scheme == "http" || scheme == "https" else { return nil }
        guard let host = url.host?.lowercased(), host.isEmpty == false else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private func mapPermission(from error: NSDictionary?) -> PermissionStatus {
        guard let error else {
            return .authorized
        }

        if let code = error[NSAppleScript.errorNumber] as? Int {
            if code == -1743 {
                return .denied
            }
            if code == -1728 || code == -1719 || code == -1712 || code == -600 {
                return .authorized
            }
        }

        return .unknown
    }

    private func runAppleScript(_ source: String) -> (output: String?, error: NSDictionary?) {
        guard let script = NSAppleScript(source: source) else {
            return (nil, [NSAppleScript.errorMessage: "Unable to create script"])
        }

        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        return (result.stringValue, error)
    }
}
