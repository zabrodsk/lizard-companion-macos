import Foundation

final class UsageTrackerService {
    private struct UsageKey: Hashable {
        let bundleID: String
        let appName: String
        let category: AppGroup
    }

    private struct DayAccumulator {
        var appTotals: [UsageKey: TimeInterval] = [:]
        var categoryTotals: [AppGroup: TimeInterval] = [:]
        var total: TimeInterval = 0
    }

    private let store: UsageStore
    private var timer: Timer?
    private var currentAppContext: AppContext?
    private var currentSegmentStart = Date()
    private var accumulators: [String: DayAccumulator] = [:]
    private var selectedRange: DashboardRange = .today

    var onUsageUpdated: (() -> Void)?

    init(store: UsageStore = UserDefaultsUsageStore()) {
        self.store = store
        hydrateFromStore()
        pruneOldData(referenceDate: Date())
    }

    func start() {
        guard timer == nil else { return }
        currentSegmentStart = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        flushCurrentSegment(until: Date())
        persist()
    }

    func setCurrentApp(_ context: AppContext, at date: Date = Date()) {
        let previousBundleID = currentAppContext?.bundleIdentifier ?? ""
        let nextBundleID = context.bundleIdentifier ?? ""
        let previousName = currentAppContext?.appName ?? ""
        if previousBundleID == nextBundleID, previousName == context.appName {
            return
        }

        flushCurrentSegment(until: date)
        currentAppContext = context
        currentSegmentStart = date
    }

    func setSelectedRange(_ range: DashboardRange) {
        selectedRange = range
        onUsageUpdated?()
    }

    func currentDashboardState() -> UsageDashboardState {
        dashboardState(for: selectedRange)
    }

    func dashboardState(for range: DashboardRange) -> UsageDashboardState {
        let keys = dateKeys(for: range, referenceDate: Date())
        let daySnapshots = keys.compactMap { snapshot(forDateKey: $0) }

        var appAggregation: [String: AppUsageEntry] = [:]
        var categoryAggregation: [AppGroup: TimeInterval] = [:]
        var total: TimeInterval = 0

        for day in daySnapshots {
            total += day.totalSeconds
            for app in day.appEntries {
                let key = "\(app.bundleID)::\(app.appName)::\(app.category.rawValue)"
                var existing = appAggregation[key] ?? AppUsageEntry(
                    bundleID: app.bundleID,
                    appName: app.appName,
                    category: app.category,
                    seconds: 0
                )
                existing.seconds += app.seconds
                appAggregation[key] = existing
            }
            for category in day.categoryEntries {
                categoryAggregation[category.category, default: 0] += category.seconds
            }
        }

        return UsageDashboardState(
            selectedRange: range,
            days: daySnapshots,
            appEntries: appAggregation.values.sorted { $0.seconds > $1.seconds },
            categoryEntries: categoryAggregation
                .map { CategoryUsageEntry(category: $0.key, seconds: $0.value) }
                .sorted { $0.seconds > $1.seconds },
            totalSeconds: total
        )
    }

    func reset() {
        accumulators = [:]
        currentAppContext = nil
        currentSegmentStart = Date()
        persist()
        onUsageUpdated?()
    }

    private func tick() {
        flushCurrentSegment(until: Date())
        currentSegmentStart = Date()
    }

    private func flushCurrentSegment(until endDate: Date) {
        guard let context = currentAppContext else {
            currentSegmentStart = endDate
            return
        }

        let startDate = currentSegmentStart
        guard endDate > startDate else { return }

        var chunkStart = startDate
        while chunkStart < endDate {
            let nextDayStart = Calendar.current.startOfDay(for: chunkStart.addingTimeInterval(86_400))
            let chunkEnd = min(endDate, nextDayStart)
            let delta = chunkEnd.timeIntervalSince(chunkStart)
            append(delta: delta, context: context, date: chunkStart)
            chunkStart = chunkEnd
        }

        currentSegmentStart = endDate
        pruneOldData(referenceDate: endDate)
        persist()
        onUsageUpdated?()
    }

    private func append(delta: TimeInterval, context: AppContext, date: Date) {
        guard delta > 0 else { return }

        let key = dateKey(for: date)
        let bundleID = context.bundleIdentifier ?? "unknown.bundle"
        let usageKey = UsageKey(bundleID: bundleID, appName: context.appName, category: context.group)

        var day = accumulators[key] ?? DayAccumulator()
        day.appTotals[usageKey, default: 0] += delta
        day.categoryTotals[context.group, default: 0] += delta
        day.total += delta
        accumulators[key] = day
    }

    private func snapshot(forDateKey key: String) -> DayUsageSnapshot? {
        guard let day = accumulators[key] else { return nil }
        let appEntries = day.appTotals
            .map { AppUsageEntry(bundleID: $0.key.bundleID, appName: $0.key.appName, category: $0.key.category, seconds: $0.value) }
            .sorted { $0.seconds > $1.seconds }

        let categoryEntries = day.categoryTotals
            .map { CategoryUsageEntry(category: $0.key, seconds: $0.value) }
            .sorted { $0.seconds > $1.seconds }

        return DayUsageSnapshot(
            dateKey: key,
            appEntries: appEntries,
            categoryEntries: categoryEntries,
            totalSeconds: day.total
        )
    }

    private func dateKeys(for range: DashboardRange, referenceDate: Date) -> [String] {
        switch range {
        case .today:
            return [dateKey(for: referenceDate)]
        case .last7Days:
            return (0..<7).compactMap { offset in
                Calendar.current.date(byAdding: .day, value: -offset, to: referenceDate).map { dateKey(for: $0) }
            }
            .reversed()
        }
    }

    private func dateKey(for date: Date) -> String {
        let formatter = Self.dateFormatter
        return formatter.string(from: date)
    }

    private func pruneOldData(referenceDate: Date) {
        let calendar = Calendar.current
        let cutoffStart = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -7, to: referenceDate) ?? referenceDate)
        let keepKeys = (0..<8).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: referenceDate).map { dateKey(for: $0) }
        }
        let keepSet = Set(keepKeys)

        accumulators = accumulators.filter { key, _ in
            if keepSet.contains(key) {
                return true
            }
            if let keyDate = Self.dateFormatter.date(from: key) {
                return keyDate >= cutoffStart
            }
            return false
        }
    }

    private func hydrateFromStore() {
        let snapshots = store.load()
        var rebuilt: [String: DayAccumulator] = [:]

        for snapshot in snapshots {
            var day = DayAccumulator()
            for app in snapshot.appEntries {
                let key = UsageKey(bundleID: app.bundleID, appName: app.appName, category: app.category)
                day.appTotals[key] = app.seconds
            }
            for category in snapshot.categoryEntries {
                day.categoryTotals[category.category] = category.seconds
            }
            day.total = snapshot.totalSeconds
            rebuilt[snapshot.dateKey] = day
        }

        accumulators = rebuilt
    }

    private func persist() {
        let snapshots = accumulators.keys.sorted().compactMap { snapshot(forDateKey: $0) }
        store.save(snapshots)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

struct UserDefaultsUsageStore: UsageStore {
    private let key = "companion.usageSnapshots"

    func load() -> [DayUsageSnapshot] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([DayUsageSnapshot].self, from: data)) ?? []
    }

    func save(_ snapshots: [DayUsageSnapshot]) {
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
