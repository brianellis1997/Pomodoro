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
    @Published var steps: [SessionStep] = []
    @Published var currentStepIndex: Int = 0

    private var timer: Timer?
    private var endDate: Date?

    var workDuration: TimeInterval = 25 * 60
    var shortBreakDuration: TimeInterval = 5 * 60
    var longBreakDuration: TimeInterval = 20 * 60
    var roundsBeforeLongBreak: Int = 4

    var autoStartBreaks: Bool = false
    var autoStartWork: Bool = false
    var onPhaseComplete: ((TimerPhase) -> Void)?
    var onPhaseAdvanced: (() -> Void)?
    var onAutoStart: (() -> Void)?

    var currentRound: Int {
        guard !steps.isEmpty else { return 1 }
        let upperBound = min(currentStepIndex, steps.count - 1)
        var focusCount = 0
        for i in 0...upperBound {
            if steps[i].kind == .focus { focusCount += 1 }
        }
        return max(1, focusCount)
    }

    var totalRounds: Int {
        max(1, steps.filter { $0.kind == .focus }.count)
    }

    var stepCount: Int { steps.count }

    var currentLabel: String {
        steps.displayLabel(at: currentStepIndex)
    }

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
        currentLabel
    }

    init() {
        steps = [SessionStep].expandLegacy(
            work: 25, shortBreak: 5, longBreak: 20,
            longBreakEvery: 4, rounds: 4
        )
        applyCurrentStepToState()
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
        currentStepIndex = 0
        applyCurrentStepToState()
    }

    func beginAdjustment() {
        timer?.invalidate()
        timer = nil
    }

    func previewAdjustment(newRemaining: TimeInterval) {
        let elapsed = max(0, totalTime - timeRemaining)
        let safeRemaining = max(60, newRemaining)
        totalTime = elapsed + safeRemaining
        timeRemaining = safeRemaining
    }

    func commitAdjustment() {
        if state == .running {
            endDate = Date().addingTimeInterval(timeRemaining)
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.tick()
                }
            }
        }
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
        state = .idle

        let completedPhase = phase
        onPhaseComplete?(completedPhase)

        advancePhase()
        onPhaseAdvanced?()

        let shouldAutoStart = (completedPhase == .work && autoStartBreaks) ||
                              ((completedPhase == .shortBreak || completedPhase == .longBreak) && autoStartWork)

        print("[TimerEngine] Phase \(completedPhase.rawValue) completed. autoStartBreaks=\(autoStartBreaks) autoStartWork=\(autoStartWork) shouldAutoStart=\(shouldAutoStart) nextPhase=\(phase.rawValue)")

        if shouldAutoStart {
            start()
            onAutoStart?()
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
        guard !steps.isEmpty else { return }
        currentStepIndex = (currentStepIndex + 1) % steps.count
        applyCurrentStepToState()
    }

    private func applyCurrentStepToState() {
        guard !steps.isEmpty else {
            phase = .work
            totalTime = workDuration
            timeRemaining = workDuration
            return
        }
        let safeIndex = min(max(0, currentStepIndex), steps.count - 1)
        let step = steps[safeIndex]
        phase = step.kind.asPhase
        totalTime = TimeInterval(step.durationMinutes * 60)
        timeRemaining = totalTime
    }

    func configure(routine: RoutineConfiguration) {
        workDuration = TimeInterval(routine.workDuration * 60)
        shortBreakDuration = TimeInterval(routine.shortBreakDuration * 60)
        longBreakDuration = TimeInterval(routine.longBreakDuration * 60)
        roundsBeforeLongBreak = routine.roundsBeforeLongBreak
        steps = routine.steps.isEmpty
            ? [SessionStep].expandLegacy(
                work: routine.workDuration,
                shortBreak: routine.shortBreakDuration,
                longBreak: routine.longBreakDuration,
                longBreakEvery: routine.roundsBeforeLongBreak,
                rounds: routine.totalRounds
              )
            : routine.steps
        reset()
    }

    func loadSteps(_ newSteps: [SessionStep], stepIndex: Int) {
        guard !newSteps.isEmpty else { return }
        steps = newSteps
        currentStepIndex = min(max(0, stepIndex), newSteps.count - 1)
        applyCurrentStepToState()
    }

    func currentStepDuration() -> TimeInterval {
        guard !steps.isEmpty else { return totalTime }
        let safeIndex = min(max(0, currentStepIndex), steps.count - 1)
        return TimeInterval(steps[safeIndex].durationMinutes * 60)
    }

    func nextStepDuration() -> TimeInterval {
        guard !steps.isEmpty else { return totalTime }
        let nextIndex = (currentStepIndex + 1) % steps.count
        return TimeInterval(steps[nextIndex].durationMinutes * 60)
    }
}
