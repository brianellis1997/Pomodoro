import Foundation
import SwiftUI
import Combine

@MainActor
class TimerViewModel: ObservableObject {
    @Published var engine = TimerEngine()

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
            }
            .store(in: &cancellables)
    }

    func startPause() {
        if isRunning {
            engine.pause()
        } else {
            engine.start()
        }
    }

    func reset() {
        engine.reset()
    }

    func skip() {
        engine.skip()
    }

    func configure(routine: Routine) {
        engine.configure(routine: routine)
    }
}
