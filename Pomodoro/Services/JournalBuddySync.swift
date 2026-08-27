import Foundation

/// Sends finished sessions to JournalBuddy.
///
/// JournalBuddy's Work habit is one timer spanning the whole day, while this
/// app already knows what actually happened inside it. Rather than logging the
/// same block twice, the timer that measured it reports it.
///
/// This talks to a generic ingest endpoint rather than anything Pomodoro
/// shaped, so the same door is open to a Shortcuts action or any other app.
/// The token is scoped to appending sessions and cannot read anything.
@MainActor
final class JournalBuddySync: ObservableObject {
    static let shared = JournalBuddySync()

    private enum Key {
        static let token = "journalBuddyIngestToken"
        static let habit = "journalBuddyHabitName"
        static let enabled = "journalBuddySyncEnabled"
        static let queue = "journalBuddyPendingSessions"
        static let lastResult = "journalBuddyLastResult"
    }

    private let endpoint = URL(string: "https://backend-production-454e.up.railway.app/api/v1/ingest/session")!
    private let defaults = UserDefaults.standard

    @Published var lastResult: String = UserDefaults.standard.string(forKey: Key.lastResult) ?? ""

    var token: String {
        get { defaults.string(forKey: Key.token) ?? "" }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.token) }
    }

    var habitName: String {
        get { defaults.string(forKey: Key.habit) ?? "Work" }
        set { defaults.set(newValue, forKey: Key.habit) }
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Key.enabled) }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }

    var isConfigured: Bool { isEnabled && !token.isEmpty }

    // MARK: - Sending

    struct Payload: Codable {
        let habit: String
        let minutes: Double
        let started_at: String
        let ended_at: String
        let source: String
        let external_id: String
        let notes: String?
    }

    /// Record a finished session. Safe to call for every session: it returns
    /// immediately when sync is off, and a failure is queued rather than lost.
    func record(id: UUID, routineName: String, minutes: Int, endedAt: Date = Date(), wasFullSession: Bool) {
        guard isConfigured, minutes > 0 else { return }

        // The offset matters. Sent without one, a 10pm session is read in the
        // server's zone and filed under tomorrow.
        let stamp = ISO8601DateFormatter()
        stamp.formatOptions = [.withInternetDateTime]
        stamp.timeZone = TimeZone.current

        let payload = Payload(
            habit: habitName,
            minutes: Double(minutes),
            started_at: stamp.string(from: endedAt.addingTimeInterval(-Double(minutes) * 60)),
            ended_at: stamp.string(from: endedAt),
            source: "Pomodoro",
            // The session's own id, so a retry cannot bank the same minutes twice.
            external_id: id.uuidString,
            notes: wasFullSession ? routineName : "\(routineName) (partial)"
        )

        Task { await send(payload, queueOnFailure: true) }
    }

    /// Retry anything an earlier send could not deliver.
    func flushQueue() {
        guard isConfigured else { return }
        let pending = queued()
        guard !pending.isEmpty else { return }
        defaults.removeObject(forKey: Key.queue)
        Task {
            for payload in pending {
                await send(payload, queueOnFailure: true)
            }
        }
    }

    /// Post one session, and confirm the habit exists by the response.
    @discardableResult
    private func send(_ payload: Payload, queueOnFailure: Bool) async -> Bool {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONEncoder().encode(payload)
        request.timeoutInterval = 20

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code == 200 {
                let dup = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])??["duplicate"] as? Bool
                setResult(dup == true ? "Already recorded" : "Sent \(Int(payload.minutes))m to \(payload.habit)")
                return true
            }
            // A bad token or a missing habit will not fix itself by retrying,
            // so those are reported rather than queued forever.
            if code == 401 {
                setResult("Token rejected. Check it in JournalBuddy.")
                return false
            }
            if code == 404 {
                setResult("No habit named \"\(payload.habit)\" in JournalBuddy.")
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

    /// Send a one-minute session and immediately retract it, so the settings
    /// screen can prove the token and habit name work without leaving a mark.
    func testConnection() async {
        guard !token.isEmpty else { setResult("Paste a token first."); return }
        let stamp = ISO8601DateFormatter()
        stamp.formatOptions = [.withInternetDateTime]
        stamp.timeZone = TimeZone.current
        let id = UUID().uuidString
        let now = Date()
        let probe = Payload(
            habit: habitName, minutes: 1,
            started_at: stamp.string(from: now.addingTimeInterval(-60)),
            ended_at: stamp.string(from: now),
            source: "Pomodoro", external_id: id, notes: "connection test"
        )
        if await send(probe, queueOnFailure: false) {
            await retract(id)
            setResult("Connected. \"\(habitName)\" found.")
        }
    }

    private func retract(_ externalId: String) async {
        var request = URLRequest(url: endpoint.appendingPathComponent(externalId))
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: request)
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
