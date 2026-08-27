import Foundation

/// Sends finished sessions to JournalBuddy.
///
/// JournalBuddy's Work habit was one timer spanning the whole day, while this
/// app already knows what actually happened inside it. Rather than logging the
/// same block twice, the timer that measured it reports it.
///
/// Steps, not routines, are what get reported. A work routine holds focus
/// blocks, breaks, and often a labelled step that is a different activity
/// entirely - thirty minutes of reading inside the work day - and collapsing
/// that into one total is what forced the reading to be logged twice.
///
/// Each routine and each step is mapped explicitly, and nothing is mapped by
/// default. A step with no mapping of its own uses the routine's, which is a
/// choice made in the picker rather than a hidden default; a routine nobody
/// has mapped sends nothing at all. An unmapped step quietly landing on Work
/// would credit work that never happened, and a record that invents an hour is
/// worse than one that misses.
@MainActor
final class JournalBuddySync: ObservableObject {
    static let shared = JournalBuddySync()

    private enum Key {
        static let token = "journalBuddyIngestToken"
        static let enabled = "journalBuddySyncEnabled"
        static let queue = "journalBuddyPendingSessions"
        static let lastResult = "journalBuddyLastResult"
        static let routeMap = "journalBuddyRoutineHabitMap"
    }

    private let base = URL(string: "https://backend-production-454e.up.railway.app/api/v1/ingest")!
    private var sessionURL: URL { base.appendingPathComponent("session") }
    private let defaults = UserDefaults.standard

    @Published var lastResult: String = UserDefaults.standard.string(forKey: Key.lastResult) ?? ""
    /// Habits fetched from JournalBuddy, so the user picks rather than types.
    @Published var habits: [Habit] = []
    @Published var isLoadingHabits = false

    struct Habit: Codable, Identifiable, Hashable {
        let id: String
        let name: String
        let unit: String?
        let target_value: Double?
        let target_direction: String?

        /// "needs 480 minutes", when the habit says so.
        var targetSummary: String? {
            guard let target_value, let unit, target_direction == "at_least" else { return nil }
            return "needs \(Int(target_value)) \(unit)"
        }
    }

    var token: String {
        get { defaults.string(forKey: Key.token) ?? "" }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.token) }
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Key.enabled) }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }

    var isConfigured: Bool { isEnabled && !token.isEmpty }

    // MARK: - Routine to habit mapping

    private var routeMap: [String: String] {
        get { defaults.dictionary(forKey: Key.routeMap) as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: Key.routeMap) }
    }

    func habitId(forRoutine routine: String) -> String? { routeMap[routine] }

    /// A step's own habit, falling back to the routine's.
    ///
    /// This fallback is a choice the user made in the picker above, not a
    /// hidden default: a routine nobody has mapped is still "Don't send", so a
    /// new routine records nothing until it is pointed somewhere.
    func habitId(forRoutine routine: String, step: String) -> String? {
        routeMap[Self.stepKey(routine, step)] ?? routeMap[routine]
    }

    func stepOverride(forRoutine routine: String, step: String) -> String? {
        routeMap[Self.stepKey(routine, step)]
    }

    func setHabit(_ habitId: String?, forRoutine routine: String, step: String) {
        setHabit(habitId, forRoutine: Self.stepKey(routine, step))
    }

    /// Keyed on the label the user sees, because a step's UUID is regenerated
    /// every launch for the built-in routines.
    static func stepKey(_ routine: String, _ step: String) -> String { "\(routine)\u{1F}\(step)" }

    func habitName(forRoutine routine: String) -> String? {
        guard let id = routeMap[routine] else { return nil }
        return habits.first { $0.id == id }?.name
    }

    func setHabit(_ habitId: String?, forRoutine routine: String) {
        var map = routeMap
        if let habitId { map[routine] = habitId } else { map.removeValue(forKey: routine) }
        routeMap = map
        objectWillChange.send()
    }

    var mappedRoutineCount: Int { routeMap.count }

    // MARK: - Sending

    struct Payload: Codable {
        let habit_id: String
        let minutes: Double
        let started_at: String
        let ended_at: String
        let source: String
        let external_id: String
        let notes: String?
    }

    /// Record one finished step of a routine.
    ///
    /// Steps are reported rather than the routine total, so a thirty minute
    /// reading block inside the work day lands on Reading instead of
    /// disappearing into eight hours of Work.
    func recordStep(routineName: String, stepLabel: String, minutes: Int) {
        guard isConfigured, minutes > 0 else { return }
        guard let habitId = habitId(forRoutine: routineName, step: stepLabel) else { return }
        send(habitId: habitId, minutes: minutes, note: "\(routineName) · \(stepLabel)",
             externalId: "\(routineName)-\(stepLabel)-\(Int(Date().timeIntervalSince1970))")
    }

    private func send(habitId: String, minutes: Int, note: String, externalId: String, endedAt: Date = Date()) {

        // The offset matters. Sent without one, a 10pm session is read in the
        // server's zone and filed under tomorrow.
        let stamp = ISO8601DateFormatter()
        stamp.formatOptions = [.withInternetDateTime]
        stamp.timeZone = TimeZone.current

        let payload = Payload(
            habit_id: habitId,
            minutes: Double(minutes),
            started_at: stamp.string(from: endedAt.addingTimeInterval(-Double(minutes) * 60)),
            ended_at: stamp.string(from: endedAt),
            source: "Pomodoro",
            // Unique per step, so a retry cannot bank the same minutes twice.
            external_id: externalId,
            notes: note
        )

        Task { await post(payload, queueOnFailure: true) }
    }

    /// Retry anything an earlier send could not deliver.
    func flushQueue() {
        guard isConfigured else { return }
        let pending = queued()
        guard !pending.isEmpty else { return }
        defaults.removeObject(forKey: Key.queue)
        Task {
            for payload in pending { await post(payload, queueOnFailure: true) }
        }
    }

    @discardableResult
    private func post(_ payload: Payload, queueOnFailure: Bool) async -> Bool {
        var request = URLRequest(url: sessionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONEncoder().encode(payload)
        request.timeoutInterval = 20

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            if code == 200 {
                let landed = body?["habit"] as? String ?? "JournalBuddy"
                let met = body?["completed_habit"] as? Bool == true
                let dup = body?["duplicate"] as? Bool == true
                setResult(dup
                    ? "Already recorded"
                    : "Sent \(Int(payload.minutes))m to \(landed)\(met ? " · target met" : "")")
                return true
            }
            // Neither a rejected token nor a deleted habit fixes itself by
            // retrying, so those are reported rather than queued forever.
            if code == 401 {
                setResult("Token rejected. Paste it again from JournalBuddy.")
                return false
            }
            if code == 404 {
                setResult("That habit no longer exists in JournalBuddy. Re-map the routine.")
                return false
            }
            setResult("JournalBuddy returned \(code)")
            if queueOnFailure { enqueue(payload) }
            return false
        } catch {
            setResult("Offline. Will retry.")
            if queueOnFailure { enqueue(payload) }
            return false
        }
    }

    // MARK: - Habits

    /// Load the habit list. Also the connection test: a token that can read
    /// this is a token that can write a session.
    func loadHabits() async {
        guard !token.isEmpty else { setResult("Paste a token first."); return }
        isLoadingHabits = true
        defer { isLoadingHabits = false }

        var request = URLRequest(url: base.appendingPathComponent("habits"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard code == 200 else {
                setResult(code == 401 ? "Token rejected." : "JournalBuddy returned \(code)")
                return
            }
            habits = try JSONDecoder().decode([Habit].self, from: data)
            // A habit deleted in JournalBuddy should not stay mapped here.
            let live = Set(habits.map(\.id))
            routeMap = routeMap.filter { live.contains($0.value) }
            setResult("Connected. \(habits.count) habits.")
        } catch {
            setResult("Could not reach JournalBuddy.")
        }
    }

    // MARK: - Offline queue

    private func queued() -> [Payload] {
        guard let data = defaults.data(forKey: Key.queue),
              let items = try? JSONDecoder().decode([Payload].self, from: data) else { return [] }
        return items
    }

    private func enqueue(_ payload: Payload) {
        var items = queued()
        guard !items.contains(where: { $0.external_id == payload.external_id }) else { return }
        items.append(payload)
        // A queue that grows without bound is a memory leak with extra steps.
        if items.count > 200 { items.removeFirst(items.count - 200) }
        defaults.set(try? JSONEncoder().encode(items), forKey: Key.queue)
    }

    var pendingCount: Int { queued().count }

    private func setResult(_ text: String) {
        lastResult = text
        defaults.set(text, forKey: Key.lastResult)
    }
}
