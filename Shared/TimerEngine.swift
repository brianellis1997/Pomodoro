import Foundation
import Combine

enum TimerPhase: String, Codable, Hashable {
    case work
    case shortBreak
    case longBreak
}

enum TimerState: String, Codable {
    case idle
    case running
    case paused
}

@MainActor
class TimerEngine: ObservableObject {
    @Published var timeRemaining: TimeInterval = 0
    @Published var totalTime: TimeInterval = 0
    @Published var phase: TimerPhase = .work
    @Published var state: TimerState = .idle
    @Published var currentRound: Int = 1
    @Published var totalRounds: Int = 4

    private var timer: Timer?
    private var endDate: Date?

    var workDuration: TimeInterval = 25 * 60
    var shortBreakDuration: TimeInterval = 5 * 60
    var longBreakDuration: TimeInterval = 20 * 60
    var roundsBeforeLongBreak: Int = 4

    var autoStartBreaks: Bool = false
    var autoStartWork: Bool = false
    var onPhaseComplete: ((TimerPhase) -> Void)?
    var onAutoStart: (() -> Void)?

    var progress: Double {
        guard totalTime > 0 else { return 1 }
        return timeRemaining / totalTime
    }

    var formattedTime: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var phaseDisplayName: String {
        switch phase {
        case .work:
            return "Focus"
        case .shortBreak:
            return "Short Break"
        case .longBreak:
            return "Long Break"
        }
    }

    init() {
        resetToWork()
    }

    func start() {
        guard state != .running else { return }

        state = .running
        endDate = Date().addingTimeInterval(timeRemaining)

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func pause() {
        guard state == .running else { return }

        state = .paused
        timer?.invalidate()
        timer = nil
        endDate = nil
    }

    func reset() {
        timer?.invalidate()
        timer = nil
        endDate = nil
        state = .idle
        currentRound = 1
        phase = .work
        resetToWork()
    }

    func skip() {
        timer?.invalidate()
        timer = nil
        endDate = nil
        state = .idle
        advancePhase()
    }

    private func tick() {
        guard let endDate = endDate else { return }

        timeRemaining = max(0, endDate.timeIntervalSinceNow)

        if timeRemaining <= 0 {
            timerCompleted()
        }
    }

    private func timerCompleted() {
        timer?.invalidate()
        timer = nil
        endDate = nil

        let completedPhase = phase
        onPhaseComplete?(completedPhase)

        advancePhase()

        let shouldAutoStart = (completedPhase == .work && autoStartBreaks) ||
                              ((completedPhase == .shortBreak || completedPhase == .longBreak) && autoStartWork)

        if shouldAutoStart {
            start()
            onAutoStart?()
        } else {
            state = .idle
        }
    }

    func ensureRunning() {
        if state == .running && timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.tick()
                }
            }
        }
    }

    private func advancePhase() {
        switch phase {
        case .work:
            if currentRound >= totalRounds {
                phase = .longBreak
                totalTime = longBreakDuration
            } else {
                phase = .shortBreak
                totalTime = shortBreakDuration
            }
        case .shortBreak:
            currentRound = min(currentRound + 1, totalRounds)
            phase = .work
            totalTime = workDuration
        case .longBreak:
            currentRound = 1
            phase = .work
            totalTime = workDuration
        }

        timeRemaining = totalTime
    }

    private func resetToWork() {
        phase = .work
        totalTime = workDuration
        timeRemaining = workDuration
    }

    func configure(routine: RoutineConfiguration) {
        workDuration = TimeInterval(routine.workDuration * 60)
        shortBreakDuration = TimeInterval(routine.shortBreakDuration * 60)
        longBreakDuration = TimeInterval(routine.longBreakDuration * 60)
        roundsBeforeLongBreak = routine.roundsBeforeLongBreak
        totalRounds = routine.totalRounds
        reset()
    }
}
