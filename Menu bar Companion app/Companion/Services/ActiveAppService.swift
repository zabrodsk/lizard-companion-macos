import AppKit
import Combine
import Foundation

final class ActiveAppService: SignalService {
    var publisher: AnyPublisher<SignalEvent, Never> {
        subject.eraseToAnyPublisher()
    }

    private let subject = PassthroughSubject<SignalEvent, Never>()
    private var observer: NSObjectProtocol?

    func start() {
        guard observer == nil else { return }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.emit(for: app)
        }

        if let current = NSWorkspace.shared.frontmostApplication {
            emit(for: current)
        }
    }

    func stop() {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            self.observer = nil
        }
    }

    private func emit(for app: NSRunningApplication) {
        let context = AppContext(
            bundleIdentifier: app.bundleIdentifier,
            appName: app.localizedName ?? "Unknown",
            group: mapGroup(bundleID: app.bundleIdentifier)
        )
        subject.send(.frontmostApp(context))
    }

    private func mapGroup(bundleID: String?) -> AppGroup {
        guard let bundleID else { return .other }

        switch bundleID {
        case "com.apple.dt.Xcode",
             "com.microsoft.VSCode",
             "com.todesktop.230313mzl4w4u92", // Cursor
             "com.apple.Terminal",
             "com.googlecode.iterm2",
             "dev.warp.Warp-Stable",
             "com.jetbrains.intellij",
             "com.jetbrains.CLion",
             "com.jetbrains.PyCharm":
            return .coding
        case "com.apple.Safari", "com.google.Chrome", "org.mozilla.firefox", "com.microsoft.edgemac", "ai.perplexity.comet", "ai.perplexity.mac":
            return .browser
        case "com.tinyspeck.slackmacgap", "com.apple.MobileSMS", "com.hnc.Discord", "ru.keepcoder.Telegram", "net.whatsapp.WhatsApp":
            return .chat
        case "com.spotify.client", "com.apple.Music", "com.apple.garageband10":
            return .music
        case "com.openai.chat", "com.openai.codex", "com.anthropic.claudefordesktop", "ai.elementlabs.lmstudio", "com.electron.ollama":
            return .ai
        case "com.microsoft.teams2", "com.microsoft.Outlook":
            return .meeting
        case "com.microsoft.Word", "com.microsoft.Excel", "com.microsoft.Powerpoint", "com.apple.iWork.Pages", "com.apple.iWork.Numbers", "com.apple.iWork.Keynote", "com.notionlabs.desktop":
            return .productivity
        case "com.raycast.macos":
            return .launcher
        case "com.electron.multiviewer-for-f1":
            return .racing
        case "com.nordvpn.NordVPN", "io.tailscale.ipn.macsys":
            return .security
        default:
            return .other
        }
    }
}
