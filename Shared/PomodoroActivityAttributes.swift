#if os(iOS)
import Foundation
import ActivityKit

struct PomodoroActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var remainingTime: TimeInterval
        var totalTime: TimeInterval
        var phase: TimerPhase
        var currentRound: Int
        var totalRounds: Int
        var isRunning: Bool
        var targetEndDate: Date
        var phaseStartDate: Date

        init(
            remainingTime: TimeInterval,
            totalTime: TimeInterval,
            phase: TimerPhase,
            currentRound: Int,
            totalRounds: Int,
            isRunning: Bool
        ) {
            self.remainingTime = remainingTime
            self.totalTime = totalTime
            self.phase = phase
            self.currentRound = currentRound
            self.totalRounds = totalRounds
            self.isRunning = isRunning
            self.targetEndDate = Date().addingTimeInterval(remainingTime)
            self.phaseStartDate = Date().addingTimeInterval(remainingTime - totalTime)
        }

        var progress: Double {
            guard totalTime > 0 else { return 0 }
            let elapsed = Date().timeIntervalSince(phaseStartDate)
            return min(max(elapsed / totalTime, 0), 1.0)
        }

        var timeString: String {
            let minutes = Int(remainingTime) / 60
            let seconds = Int(remainingTime) % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }

        var phaseEmoji: String {
            switch phase {
            case .work: return "🍅"
            case .shortBreak: return "☕️"
            case .longBreak: return "🌴"
            }
        }

        var phaseLabel: String {
            switch phase {
            case .work: return "Focus"
            case .shortBreak: return "Short Break"
            case .longBreak: return "Long Break"
            }
        }
    }

    var routineName: String

    init(routineName: String) {
        self.routineName = routineName
    }
}
#endif
