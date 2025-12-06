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
    }
}

extension Notification.Name {
    static let routinesReceived = Notification.Name("routinesReceived")
    static let routinesRequested = Notification.Name("routinesRequested")
    static let timerStateReceived = Notification.Name("timerStateReceived")
}
