import AppKit
import Combine
import Foundation

final class SpotifyService: SignalService {
    var publisher: AnyPublisher<SignalEvent, Never> {
        subject.eraseToAnyPublisher()
    }

    private let subject = PassthroughSubject<SignalEvent, Never>()
    private var timer: Timer?
    private(set) var permissionStatus: PermissionStatus = .unknown
    var enabled = false

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 6, repeats: true) { [weak self] _ in
            self?.emitState(shouldProbePlayback: self?.enabled ?? false)
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
        emitState(shouldProbePlayback: false)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func requestPermission() {
        guard isSpotifyInstalled else {
            permissionStatus = .unavailable
            emitState(shouldProbePlayback: false)
            return
        }

        // Intentionally touches Spotify via Apple Events to trigger the system consent prompt.
        let result = runAppleScript("tell application id \"com.spotify.client\" to version")
        permissionStatus = mapPermission(from: result.error)
        emitState(shouldProbePlayback: true)
    }

    private var isSpotifyInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.spotify.client") != nil
    }

    private var isSpotifyRunning: Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty == false
    }

    private func emitState(shouldProbePlayback: Bool) {
        guard isSpotifyInstalled else {
            subject.send(.spotify(MusicState(isSpotifyInstalled: false, isPlaying: false, permissionStatus: .unavailable)))
            return
        }

        if permissionStatus == .unknown {
            permissionStatus = .unknown
        }

        let isPlaying: Bool
        if shouldProbePlayback, isSpotifyRunning {
            let probe = runAppleScript(
                """
                set spotifyRunning to application id "com.spotify.client" is running
                if spotifyRunning then
                    tell application id "com.spotify.client"
                        if player state is playing then
                            return "playing"
                        else
                            return "paused"
                        end if
                    end tell
                end if
                return "stopped"
                """
            )
            permissionStatus = mapPermission(from: probe.error)
            let stateText = probe.output?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            isPlaying = stateText == "playing"
        } else {
            isPlaying = false
        }

        subject.send(.spotify(MusicState(isSpotifyInstalled: true, isPlaying: isPlaying, permissionStatus: permissionStatus)))
    }

    private func mapPermission(from error: NSDictionary?) -> PermissionStatus {
        guard let error else {
            return .authorized
        }

        if let code = error[NSAppleScript.errorNumber] as? Int {
            if code == -1743 {
                return .denied
            }
            if code == -600 {
                return .authorized
            }
            if code == -1728 {
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
