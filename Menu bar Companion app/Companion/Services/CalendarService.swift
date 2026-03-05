import Combine
import EventKit
import Foundation

final class CalendarService: SignalService {
    var publisher: AnyPublisher<SignalEvent, Never> {
        subject.eraseToAnyPublisher()
    }

    private let subject = PassthroughSubject<SignalEvent, Never>()
    private let store = EKEventStore()
    private var timer: Timer?
    private(set) var permissionStatus: PermissionStatus = .unknown
    var enabled = false
    var leadMinutes = CompanionDefaults.meetingLeadMinutesDefault

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.emitState()
        }
        RunLoop.main.add(timer!, forMode: .common)
        refreshAuthorizationStatus()
        emitState()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func requestPermission() {
        store.requestFullAccessToEvents { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.permissionStatus = granted ? .authorized : .denied
                self?.emitState()
            }
        }
    }

    private func refreshAuthorizationStatus() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .writeOnly:
            permissionStatus = .authorized
        case .denied, .restricted:
            permissionStatus = .denied
        case .notDetermined:
            permissionStatus = .unknown
        @unknown default:
            permissionStatus = .unknown
        }
    }

    private func emitState() {
        refreshAuthorizationStatus()

        guard enabled, permissionStatus == .authorized else {
            subject.send(.calendar(CalendarState(permissionStatus: permissionStatus, meetingSoon: false, nextMeetingDate: nil)))
            return
        }

        let now = Date()
        let horizon = now.addingTimeInterval(TimeInterval(max(1, leadMinutes) * 60))
        let predicate = store.predicateForEvents(withStart: now, end: now.addingTimeInterval(4 * 3600), calendars: nil)
        let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        let nextMeeting = events.first(where: { !$0.isAllDay && $0.startDate >= now })
        let meetingSoon = nextMeeting.map { $0.startDate <= horizon } ?? false

        subject.send(.calendar(CalendarState(permissionStatus: permissionStatus, meetingSoon: meetingSoon, nextMeetingDate: nextMeeting?.startDate)))
    }
}
