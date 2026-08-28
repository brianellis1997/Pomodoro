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
    /// The step that just finished, and how long it ran.
    ///
    /// A routine is not one block. A work routine holds focus steps, breaks,
    /// and often a labelled step that is a different activity entirely - thirty
    /// minutes of reading inside the work day. Reporting only the routine total
    /// makes those invisible and forces the reading to be logged twice.
    var onStepComplete: ((SessionStep, Int, Date) -> Void)?
    var onPhaseAdvanced: (() -> Void)?
    var onAutoStart: (() -> Void)?
    var onWorkPhaseSkipped: ((Int) -> Void)?

    private(set) var lastCompletedTimeRemaining: TimeInterval = 0
    private(set) var didWrapRoutine: Bool = false

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
        let safeRemaining = max(60, min(newRemaining, totalTime))
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

    /// Skip a step that has already elapsed, reporting it as it goes.
    ///
    /// `skip()` deliberately reports nothing, because a step the user chose to
    /// skip did not happen. A step the clock ran through while the app was
    /// closed did happen, and the two must not share a path.
    func consumeElapsedStep(endedAt: Date) {
        if steps.indices.contains(currentStepIndex) {
            onStepComplete?(steps[currentStepIndex], Int(currentStepDuration() / 60), endedAt)
        }
        timeRemaining = 0
        skip()
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

        // Compute how far past endDate we are. If the app was suspended for a long
        // time before this tick fired, this overflow accounts for the time that
        // would have elapsed in subsequent phases.
        let overflowFromEndDate: TimeInterval
        if let endDate = endDate {
            overflowFromEndDate = max(0, -endDate.timeIntervalSinceNow)
        } else {
            overflowFromEndDate = 0
        }
        // When the step actually ended, which is not now if the app was
        // suspended through it. Reporting these as "now" would stack a day of
        // sessions on one instant, and anything merging overlapping spans
        // would read eight hours as fifty minutes.
        let stepEndedAt = endDate ?? Date()
        endDate = nil
        state = .idle

        let completedPhase = phase
        let completedPhaseDurationMinutes = Int(totalTime / 60)
        // Fired before advancePhase, while currentStepIndex still names the
        // step that just ended.
        if steps.indices.contains(currentStepIndex) {
            onStepComplete?(steps[currentStepIndex], completedPhaseDurationMinutes, stepEndedAt)
        }
        onPhaseComplete?(completedPhase)

        advancePhase()
        onPhaseAdvanced?()

        let shouldAutoStart = !didWrapRoutine && (
            (completedPhase == .work && autoStartBreaks) ||
            ((completedPhase == .shortBreak || completedPhase == .longBreak) && autoStartWork)
        )

        print("[TimerEngine] timerCompleted phase=\(completedPhase.rawValue) → \(phase.rawValue) overflow=\(overflowFromEndDate)s didWrapRoutine=\(didWrapRoutine) shouldAutoStart=\(shouldAutoStart) (autoBreaks=\(autoStartBreaks) autoWork=\(autoStartWork))")

        if shouldAutoStart {
            let remainingOverflow = consumeOverflowChain(initial: overflowFromEndDate, from: stepEndedAt)
            if didWrapRoutine {
                return
            }
            if completedPhase == .work && phase == .work {
                onWorkPhaseSkipped?(completedPhaseDurationMinutes)
            }
            if remainingOverflow > 0 && remainingOverflow < totalTime {
                timeRemaining = max(60, totalTime - remainingOverflow)
            }
            start()
            onAutoStart?()
        }
    }

    /// Fast-forward through steps that elapsed while the app was suspended.
    ///
    /// These used to advance silently, which is why a full eight hour routine
    /// reported under six: only the steps that happened to finish with the app
    /// open were ever reported. Each one is announced with the time it really
    /// ended, walked forward from the end of the step that woke us.
    private func consumeOverflowChain(initial: TimeInterval, from base: Date) -> TimeInterval {
        var remaining = initial
        var clock = base
        let maxChain = 16
        var advances = 0
        while remaining > 0 && !didWrapRoutine && advances < maxChain {
            let safeIndex = min(max(0, currentStepIndex), max(0, steps.count - 1))
            guard !steps.isEmpty else { break }
            let kind = steps[safeIndex].kind
            let nextAutoStart = (kind == .focus) ? autoStartBreaks : autoStartWork
            let currentDuration = currentStepDuration()
            if !nextAutoStart || remaining < currentDuration {
                break
            }
            if kind == .focus {
                onWorkPhaseSkipped?(Int(currentDuration / 60))
            }
            clock = clock.addingTimeInterval(currentDuration)
            onStepComplete?(steps[safeIndex], Int(currentDuration / 60), clock)
            remaining -= currentDuration
            advancePhase()
            advances += 1
        }
        return remaining
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
        lastCompletedTimeRemaining = max(0, timeRemaining)
        let nextIndex = currentStepIndex + 1
        if nextIndex >= steps.count {
            didWrapRoutine = true
            currentStepIndex = 0
        } else {
            didWrapRoutine = false
            currentStepIndex = nextIndex
        }
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
