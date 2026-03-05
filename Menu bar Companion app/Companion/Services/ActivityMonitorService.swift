import AppKit
import Combine
import Foundation

final class ActivityMonitorService: SignalService {
    var publisher: AnyPublisher<SignalEvent, Never> {
        subject.eraseToAnyPublisher()
    }

    private let subject = PassthroughSubject<SignalEvent, Never>()
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var timer: Timer?
    private var lastInputDate = Date()

    func start() {
        guard timer == nil else { return }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .mouseMoved, .scrollWheel, .otherMouseDown, .flagsChanged]) { [weak self] event in
            self?.registerInput()
            return event
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .mouseMoved, .scrollWheel, .otherMouseDown, .flagsChanged]) { [weak self] _ in
            self?.registerInput()
        }

        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.emitState()
        }
        RunLoop.main.add(timer!, forMode: .common)
        emitState()
    }

    func stop() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        timer?.invalidate()
        timer = nil
    }

    private func registerInput() {
        lastInputDate = Date()
    }

    private func emitState() {
        let idleSeconds = Date().timeIntervalSince(lastInputDate)
        let state = ActivityState(
            isIdle: idleSeconds >= 90,
            lastInputDate: lastInputDate,
            intensity: max(0, min(1, 1 - (idleSeconds / 90)))
        )
        subject.send(.activity(state))
    }
}
