import Foundation
import SwiftUI
import Combine
import WidgetKit

@MainActor
class TimerViewModel: ObservableObject {
    @Published var engine = TimerEngine()
    @Published var currentRoutineName: String = "Classic Pomodoro"

    private let liveActivityManager = LiveActivityManager.shared

    var timeRemaining: TimeInterval { engine.timeRemaining }
    var totalTime: TimeInterval { engine.totalTime }
    var phase: TimerPhase { engine.phase }
    var state: TimerState { engine.state }
    var currentRound: Int { engine.currentRound }
    var totalRounds: Int { engine.totalRounds }
    var progress: Double { engine.progress }
    var formattedTime: String { engine.formattedTime }
    var phaseDisplayName: String { engine.phaseDisplayName }

    var isRunning: Bool { state == .running }
    var isPaused: Bool { state == .paused }
    var isIdle: Bool { state == .idle }

    var phaseColor: Color {
        switch phase {
        case .work:
            return .pomodoroRed
        case .shortBreak:
            return .pomodoroGreen
        case .longBreak:
            return .pomodoroBlue
        }
    }

    var roundsDisplay: String {
        "Round \(currentRound) of \(totalRounds)"
    }

    private var cancellables = Set<AnyCancellable>()

    init() {
        engine.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
                self?.syncLiveActivity()
                self?.syncWidgetData()
            }
            .store(in: &cancellables)

        syncWidgetData()
        checkPendingWidgetActions()
    }

    func checkPendingWidgetActions() {
        let defaults = UserDefaults(suiteName: "group.com.bdogellis.pomodoro")

        guard defaults?.bool(forKey: "pendingAction") == true else { return }

        let actionType = defaults?.string(forKey: "actionType") ?? ""

        defaults?.set(false, forKey: "pendingAction")
        defaults?.removeObject(forKey: "actionType")

        switch actionType {
        case "start":
            if !isRunning {
                engine.start()
                syncLiveActivity()
            }
        case "pause":
            if isRunning {
                engine.pause()
                syncLiveActivity()
            }
        case "reset":
            reset()
        case "skip":
            skip()
        default:
            break
        }
    }

    func startPause() {
        if isRunning {
            engine.pause()
        } else {
            engine.start()
        }
        syncLiveActivity()
    }

    func reset() {
        engine.reset()
        liveActivityManager.endActivity()
        syncWidgetData()
    }

    func skip() {
        engine.skip()
        syncLiveActivity()
    }

    func configure(routine: Routine) {
        currentRoutineName = routine.name
        engine.configure(routine: routine.configuration)
        syncWidgetData()
    }

    func configure(with config: RoutineConfiguration) {
        currentRoutineName = config.name
        engine.configure(routine: config)
        syncWidgetData()
    }

    private func syncLiveActivity() {
        liveActivityManager.syncTimerState(
            timeRemaining: timeRemaining,
            totalTime: totalTime,
            phase: phase,
            currentRound: currentRound,
            totalRounds: totalRounds,
            isRunning: isRunning,
            routineName: currentRoutineName
        )
    }

    private func syncWidgetData() {
        let defaults = UserDefaults(suiteName: "group.com.bdogellis.pomodoro")
        defaults?.set(timeRemaining, forKey: "remainingTime")
        defaults?.set(totalTime, forKey: "totalTime")
        defaults?.set(phase.rawValue, forKey: "phase")
        defaults?.set(currentRound, forKey: "currentRound")
        defaults?.set(totalRounds, forKey: "totalRounds")
        defaults?.set(isRunning, forKey: "isRunning")
        defaults?.set(currentRoutineName, forKey: "routineName")

        if isRunning {
            let endTime = Date().addingTimeInterval(timeRemaining)
            defaults?.set(endTime.timeIntervalSince1970, forKey: "endTime")
        } else {
            defaults?.removeObject(forKey: "endTime")
        }

        WidgetCenter.shared.reloadAllTimelines()
    }
}
