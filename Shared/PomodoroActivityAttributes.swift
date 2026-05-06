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
        var phaseLabel: String
        var stepIndex: Int
        var stepCount: Int

        init(
            remainingTime: TimeInterval,
            totalTime: TimeInterval,
            phase: TimerPhase,
            currentRound: Int,
            totalRounds: Int,
            isRunning: Bool,
            phaseLabel: String? = nil,
            stepIndex: Int = 0,
            stepCount: Int = 0
        ) {
            self.remainingTime = remainingTime
            self.totalTime = totalTime
            self.phase = phase
            self.currentRound = currentRound
            self.totalRounds = totalRounds
            self.isRunning = isRunning
            self.targetEndDate = Date().addingTimeInterval(remainingTime)
            self.phaseStartDate = Date().addingTimeInterval(remainingTime - totalTime)
            self.phaseLabel = phaseLabel ?? Self.defaultLabel(for: phase)
            self.stepIndex = stepIndex
            self.stepCount = stepCount
        }

        private enum CodingKeys: String, CodingKey {
            case remainingTime, totalTime, phase, currentRound, totalRounds
            case isRunning, targetEndDate, phaseStartDate
            case phaseLabel, stepIndex, stepCount
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.remainingTime = try c.decode(TimeInterval.self, forKey: .remainingTime)
            self.totalTime = try c.decode(TimeInterval.self, forKey: .totalTime)
            self.phase = try c.decode(TimerPhase.self, forKey: .phase)
            self.currentRound = try c.decode(Int.self, forKey: .currentRound)
            self.totalRounds = try c.decode(Int.self, forKey: .totalRounds)
            self.isRunning = try c.decode(Bool.self, forKey: .isRunning)
            self.targetEndDate = try c.decode(Date.self, forKey: .targetEndDate)
            self.phaseStartDate = try c.decode(Date.self, forKey: .phaseStartDate)
            self.phaseLabel = try c.decodeIfPresent(String.self, forKey: .phaseLabel) ?? Self.defaultLabel(for: phase)
            self.stepIndex = try c.decodeIfPresent(Int.self, forKey: .stepIndex) ?? 0
            self.stepCount = try c.decodeIfPresent(Int.self, forKey: .stepCount) ?? 0
        }

        private static func defaultLabel(for phase: TimerPhase) -> String {
            switch phase {
            case .work: return "Focus"
            case .shortBreak: return "Short Break"
            case .longBreak: return "Long Break"
            }
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

        var stepCounterText: String {
            guard stepCount > 0 else { return "" }
            return "Step \(stepIndex + 1) of \(stepCount)"
        }
    }

    var routineName: String

    init(routineName: String) {
        self.routineName = routineName
    }
}
#endif
