import Foundation
import SwiftUI
import UIKit
import Combine
import WidgetKit
import UserNotifications

@MainActor
class TimerViewModel: ObservableObject {
    @Published var engine = TimerEngine()
    @Published var currentRoutineName: String = "Classic Pomodoro"
    @Published var focusModeEnabled: Bool = false
    @Published var sessionFailed: Bool = false
    @Published var focusModeViolationCount: Int = 0
    @Published var showCloseCallMessage: Bool = false

    static let focusGracePeriod: TimeInterval = 5.0

    var spotifyEnabled: Bool = false
    var spotifyStudyPlaylistUri: String?
    var spotifyBreakPlaylistUri: String?

    private var focusModeGraceUntil: Date?
    private var backgroundStartTime: Date?

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

        engine.onAutoStart = { [weak self] in
            self?.handleAutoStart()
        }

        restoreTimerState()
        syncWidgetData()
        checkPendingWidgetActions()
        requestNotificationPermission()
    }

    private func handleAutoStart() {
        saveTimerState()
        scheduleTimerNotification()
        syncLiveActivity()
        triggerSpotifyPlayback()
    }

    func onAppBecameActive() {
        engine.ensureRunning()
        if isRunning {
            liveActivityManager.forceStartActivity(
                routineName: currentRoutineName,
                timeRemaining: timeRemaining,
                totalTime: totalTime,
                phase: phase,
                currentRound: currentRound,
                totalRounds: totalRounds
            )
        }
        checkPendingWidgetActions()
        handleFocusModeReturn()
    }

    private func handleFocusModeReturn() {
        guard let startTime = backgroundStartTime else { return }
        backgroundStartTime = nil

        let timeAway = Date().timeIntervalSince(startTime)

        if timeAway < Self.focusGracePeriod {
            cancelScheduledViolationNotification()

            if !sessionFailed {
                showCloseCallMessage = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                    self?.showCloseCallMessage = false
                }
            }
        } else {
            triggerFocusViolation()
        }
    }

    func updateSettings(
        autoStartBreaks: Bool,
        autoStartWork: Bool,
        focusModeEnabled: Bool,
        spotifyEnabled: Bool = false,
        spotifyStudyPlaylistUri: String? = nil,
        spotifyBreakPlaylistUri: String? = nil
    ) {
        engine.autoStartBreaks = autoStartBreaks
        engine.autoStartWork = autoStartWork
        self.focusModeEnabled = focusModeEnabled
        self.spotifyEnabled = spotifyEnabled
        self.spotifyStudyPlaylistUri = spotifyStudyPlaylistUri
        self.spotifyBreakPlaylistUri = spotifyBreakPlaylistUri
    }

    func onAppWentToBackground() {
        guard focusModeEnabled && isRunning && phase == .work else { return }

        if let graceUntil = focusModeGraceUntil, Date() < graceUntil {
            return
        }

        let brightnessAtBackground = UIScreen.main.brightness

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }

            let currentBrightness = UIScreen.main.brightness
            let screenLikelyOff = currentBrightness < 0.01 || brightnessAtBackground < 0.01

            if screenLikelyOff {
                return
            }

            self.backgroundStartTime = Date()
            self.sendGracePeriodWarningNotification()
            self.scheduleViolationNotification()
        }
    }

    private func sendGracePeriodWarningNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Come Back!"
        content.body = "Return to the app within \(Int(Self.focusGracePeriod)) seconds to avoid a focus mode violation!"
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: "focusGraceWarning",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func scheduleViolationNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Focus Mode Violation!"
        content.body = "Time's up! Your points will be reduced to 50% and you won't receive streak bonus."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Self.focusGracePeriod, repeats: false)
        let request = UNNotificationRequest(
            identifier: "focusGraceViolation",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func cancelScheduledViolationNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["focusGraceViolation"])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["focusGraceWarning"])
    }

    private func triggerFocusViolation() {
        guard !sessionFailed else { return }
        focusModeViolationCount += 1
        sessionFailed = true
        backgroundStartTime = nil
    }

    func setFocusModeGrace(seconds: TimeInterval) {
        focusModeGraceUntil = Date().addingTimeInterval(seconds)
    }

    func resetFocusModeViolation() {
        sessionFailed = false
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
            triggerSpotifyPlayback()
        }
        saveTimerState()
        syncLiveActivity()
    }

    private func triggerSpotifyPlayback() {
        guard spotifyEnabled else { return }

        let playlistUri: String?
        if phase == .work {
            playlistUri = spotifyStudyPlaylistUri
        } else {
            playlistUri = spotifyBreakPlaylistUri
        }

        guard let uri = playlistUri else { return }

        setFocusModeGrace(seconds: 3)
        SpotifyService.shared.openPlaylist(uri)
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
