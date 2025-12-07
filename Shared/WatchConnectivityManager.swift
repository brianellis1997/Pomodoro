import Foundation
import WatchConnectivity
import Combine

struct RoutineTransfer: Codable {
    let id: String
    let name: String
    let workDuration: Int
    let shortBreakDuration: Int
    let longBreakDuration: Int
    let roundsBeforeLongBreak: Int
    let totalRounds: Int
}

struct SessionCompletion: Codable {
    let routineName: String
    let durationMinutes: Int
    let wasFullSession: Bool
    let completedAt: Date
}

struct StatsUpdate: Codable {
    let totalSessions: Int
    let totalMinutes: Int
    let currentStreak: Int
    let todaySessions: Int
    let totalPoints: Int
    let level: Int
}

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var receivedRoutines: [RoutineTransfer] = []
    @Published var isReachable = false
    @Published var isPaired = false
    @Published var isWatchAppInstalled = false

    private var session: WCSession?

    override init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    func sendRoutines(_ routines: [RoutineTransfer]) {
        guard let session = session, session.activationState == .activated else { return }

        do {
            let data = try JSONEncoder().encode(routines)
            let message = ["routines": data]

            #if os(iOS)
            if session.isReachable {
                session.sendMessage(message, replyHandler: nil, errorHandler: { error in
                    print("Error sending message: \(error)")
                })
            } else {
                try session.updateApplicationContext(message)
            }
            #else
            if session.isReachable {
                session.sendMessage(message, replyHandler: nil, errorHandler: { error in
                    print("Error sending message: \(error)")
                })
            }
            #endif
        } catch {
            print("Error encoding routines: \(error)")
        }
    }

    func sendTimerState(
        timeRemaining: TimeInterval,
        totalTime: TimeInterval,
        phase: TimerPhase,
        currentRound: Int,
        totalRounds: Int,
        isRunning: Bool,
        routineName: String
    ) {
        guard let session = session, session.activationState == .activated else { return }

        let message: [String: Any] = [
            "timerState": [
                "timeRemaining": timeRemaining,
                "totalTime": totalTime,
                "phase": phase.rawValue,
                "currentRound": currentRound,
                "totalRounds": totalRounds,
                "isRunning": isRunning,
                "routineName": routineName
            ]
        ]

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: nil)
        }
    }

    func requestRoutines() {
        guard let session = session, session.activationState == .activated, session.isReachable else { return }

        session.sendMessage(["requestRoutines": true], replyHandler: nil, errorHandler: nil)
    }

    func sendSessionCompletion(_ completion: SessionCompletion) {
        guard let session = session, session.activationState == .activated else { return }

        do {
            let data = try JSONEncoder().encode(completion)
            let message = ["sessionCompletion": data]

            if session.isReachable {
                session.sendMessage(message, replyHandler: nil, errorHandler: { error in
                    print("Error sending session completion: \(error)")
                })
            } else {
                try session.updateApplicationContext(message)
            }
        } catch {
            print("Error encoding session completion: \(error)")
        }
    }

    func sendStatsUpdate(_ stats: StatsUpdate) {
        guard let session = session, session.activationState == .activated else { return }

        do {
            let data = try JSONEncoder().encode(stats)
            let message = ["statsUpdate": data]

            if session.isReachable {
                session.sendMessage(message, replyHandler: nil, errorHandler: { error in
                    print("Error sending stats update: \(error)")
                })
            } else {
                try session.updateApplicationContext(message)
            }
        } catch {
            print("Error encoding stats update: \(error)")
        }
    }

    func requestStats() {
        guard let session = session, session.activationState == .activated, session.isReachable else { return }

        session.sendMessage(["requestStats": true], replyHandler: nil, errorHandler: nil)
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            #if os(iOS)
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            #endif
            self.isReachable = session.isReachable
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) { }

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isReachable = session.isReachable
        }
    }
    #endif

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        processMessage(message)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        processMessage(applicationContext)
    }

    private func processMessage(_ message: [String: Any]) {
        if let routinesData = message["routines"] as? Data {
            do {
                let routines = try JSONDecoder().decode([RoutineTransfer].self, from: routinesData)
                DispatchQueue.main.async {
                    self.receivedRoutines = routines
                    NotificationCenter.default.post(name: .routinesReceived, object: routines)
                }
            } catch {
                print("Error decoding routines: \(error)")
            }
        }

        if message["requestRoutines"] != nil {
            NotificationCenter.default.post(name: .routinesRequested, object: nil)
        }

        if let timerState = message["timerState"] as? [String: Any] {
            NotificationCenter.default.post(name: .timerStateReceived, object: timerState)
        }

        if let sessionData = message["sessionCompletion"] as? Data {
            do {
                let session = try JSONDecoder().decode(SessionCompletion.self, from: sessionData)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .sessionCompletionReceived, object: session)
                }
            } catch {
                print("Error decoding session completion: \(error)")
            }
        }

        if let statsData = message["statsUpdate"] as? Data {
            do {
                let stats = try JSONDecoder().decode(StatsUpdate.self, from: statsData)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .statsUpdateReceived, object: stats)
                }
            } catch {
                print("Error decoding stats update: \(error)")
            }
        }

        if message["requestStats"] != nil {
            NotificationCenter.default.post(name: .statsRequested, object: nil)
        }
    }
}

extension Notification.Name {
    static let routinesReceived = Notification.Name("routinesReceived")
    static let routinesRequested = Notification.Name("routinesRequested")
    static let timerStateReceived = Notification.Name("timerStateReceived")
    static let sessionCompletionReceived = Notification.Name("sessionCompletionReceived")
    static let statsUpdateReceived = Notification.Name("statsUpdateReceived")
    static let statsRequested = Notification.Name("statsRequested")
}
