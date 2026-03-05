import Combine
import Foundation
import IOKit.ps

final class BatteryService: SignalService {
    var publisher: AnyPublisher<SignalEvent, Never> {
        subject.eraseToAnyPublisher()
    }

    private let subject = PassthroughSubject<SignalEvent, Never>()
    private var timer: Timer?
    var lowBatteryThreshold = CompanionDefaults.batteryThresholdDefault

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
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

    private func emitState() {
        let level = currentBatteryPercentage()
        let charging = isCharging()
        let state = BatteryState(level: level, isCharging: charging, isLowBattery: !charging && level <= lowBatteryThreshold)
        subject.send(.battery(state))
    }

    private func currentBatteryPercentage() -> Int {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let list = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as? [CFTypeRef] ?? []

        guard
            let source = list.first,
            let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
            let current = description[kIOPSCurrentCapacityKey as String] as? Int,
            let max = description[kIOPSMaxCapacityKey as String] as? Int,
            max > 0
        else {
            return 100
        }

        return Int((Double(current) / Double(max)) * 100)
    }

    private func isCharging() -> Bool {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let list = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as? [CFTypeRef] ?? []

        guard
            let source = list.first,
            let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
            let powerSourceState = description[kIOPSPowerSourceStateKey as String] as? String
        else {
            return false
        }

        return powerSourceState == kIOPSACPowerValue
    }
}
