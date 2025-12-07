import Foundation
import SwiftUI
import Combine
import WidgetKit
import UserNotifications

@MainActor
class TimerViewModel: ObservableObject {
    @Published var engine = TimerEngine()
    @Published var currentRoutineName: String = "Classic Pomodoro"

    private let liveActivityManager = LiveActivityManager.shared
    private let defaults = UserDefaults(suiteName: "group.com.bdogellis.pomodoro")

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

        engine.onPhaseComplete = { [weak self] completedPhase in
            self?.handlePhaseComplete(completedPhase)
        }

        restoreTimerState()
        syncWidgetData()
        checkPendingWidgetActions()
        requestNotificationPermission()
    }

    func updateSettings(autoStartBreaks: Bool, autoStartWork: Bool) {
        engine.autoStartBreaks = autoStartBreaks
        engine.autoStartWork = autoStartWork
    }

    private func handlePhaseComplete(_ phase: TimerPhase) {
        scheduleCompletionNotification(for: phase)
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func scheduleTimerNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["timerComplete"])

        guard isRunning else { return }

        let content = UNMutableNotificationContent()
        content.title = phase == .work ? "Focus Session Complete!" : "Break Time Over!"
        content.body = phase == .work ? "Time for a break. Great work!" : "Ready to focus again?"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeRemaining, repeats: false)
        let request = UNNotificationRequest(identifier: "timerComplete", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    private func cancelTimerNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["timerComplete"])
    }

    private func scheduleCompletionNotification(for phase: TimerPhase) {
        let content = UNMutableNotificationContent()
        content.title = phase == .work ? "Focus Session Complete!" : "Break Time Over!"
        content.body = phase == .work ? "Time for a break. Great work!" : "Ready to focus again?"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: "phaseComplete-\(UUID().uuidString)", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    private func saveTimerState() {
        defaults?.set(timeRemaining, forKey: "savedTimeRemaining")
        defaults?.set(totalTime, forKey: "savedTotalTime")
        defaults?.set(phase.rawValue, forKey: "savedPhase")
        defaults?.set(currentRound, forKey: "savedCurrentRound")
        defaults?.set(totalRounds, forKey: "savedTotalRounds")
        defaults?.set(currentRoutineName, forKey: "savedRoutineName")
        defaults?.set(isRunning, forKey: "savedIsRunning")
        defaults?.set(engine.workDuration, forKey: "savedWorkDuration")
        defaults?.set(engine.shortBreakDuration, forKey: "savedShortBreakDuration")
        defaults?.set(engine.longBreakDuration, forKey: "savedLongBreakDuration")

        if isRunning {
            let endTime = Date().addingTimeInterval(timeRemaining)
            defaults?.set(endTime.timeIntervalSince1970, forKey: "savedEndTime")
        } else {
            defaults?.removeObject(forKey: "savedEndTime")
        }
    }

    private func restoreTimerState() {
        guard let savedEndTime = defaults?.double(forKey: "savedEndTime"),
              savedEndTime > 0,
              defaults?.bool(forKey: "savedIsRunning") == true else {
            return
        }

        let endDate = Date(timeIntervalSince1970: savedEndTime)
        let now = Date()

        guard endDate > now else {
            clearSavedState()
            return
        }

        if let savedPhase = defaults?.string(forKey: "savedPhase"),
           let phase = TimerPhase(rawValue: savedPhase) {
            engine.phase = phase
        }

        engine.totalTime = defaults?.double(forKey: "savedTotalTime") ?? 25 * 60
        engine.currentRound = defaults?.integer(forKey: "savedCurrentRound") ?? 1
        engine.totalRounds = defaults?.integer(forKey: "savedTotalRounds") ?? 4
        engine.workDuration = defaults?.double(forKey: "savedWorkDuration") ?? 25 * 60
        engine.shortBreakDuration = defaults?.double(forKey: "savedShortBreakDuration") ?? 5 * 60
        engine.longBreakDuration = defaults?.double(forKey: "savedLongBreakDuration") ?? 20 * 60
        currentRoutineName = defaults?.string(forKey: "savedRoutineName") ?? "Classic Pomodoro"

        engine.timeRemaining = endDate.timeIntervalSince(now)
        engine.start()
    }

    private func clearSavedState() {
        defaults?.removeObject(forKey: "savedEndTime")
        defaults?.removeObject(forKey: "savedIsRunning")
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
            cancelTimerNotification()
        } else {
            engine.start()
            scheduleTimerNotification()
        }
        saveTimerState()
        syncLiveActivity()
    }

    func reset() {
        engine.reset()
        cancelTimerNotification()
        clearSavedState()
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
