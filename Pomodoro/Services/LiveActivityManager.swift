import Foundation
import ActivityKit
import WidgetKit

@MainActor
class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<PomodoroActivityAttributes>?
    private var currentRoutineName: String = "Classic Pomodoro"

    private let appGroupDefaults = UserDefaults(suiteName: "group.com.bdogellis.pomodoro")

    private init() {}

    var isActivityActive: Bool {
        currentActivity != nil
    }

    func startActivity(routineName: String, state: PomodoroActivityAttributes.ContentState) {
        let authInfo = ActivityAuthorizationInfo()
        print("Live Activities enabled: \(authInfo.areActivitiesEnabled)")
        print("Frequent push enabled: \(authInfo.frequentPushesEnabled)")

        guard authInfo.areActivitiesEnabled else {
            print("Live Activities are not enabled - check Settings > Pomodoro > Live Activities")
            return
        }

        for activity in Activity<PomodoroActivityAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }

        let attributes = PomodoroActivityAttributes(routineName: routineName)
        currentRoutineName = routineName

        let staleDate = state.isRunning ? Date().addingTimeInterval(state.remainingTime + 60) : Date().addingTimeInterval(300)

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: staleDate),
                pushType: nil
            )
            print("Live Activity started successfully")
            syncToWidget(state: state, routineName: routineName)
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    func updateActivity(state: PomodoroActivityAttributes.ContentState) {
        guard let activity = currentActivity else { return }

        let staleDate = state.isRunning ? Date().addingTimeInterval(state.remainingTime + 60) : Date().addingTimeInterval(300)

        Task {
            await activity.update(
                ActivityContent(state: state, staleDate: staleDate)
            )
            syncToWidget(state: state, routineName: currentRoutineName)
        }
    }

    func endAllActivities() {
        Task {
            for activity in Activity<PomodoroActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    func endActivity() {
        guard let activity = currentActivity else { return }

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            currentActivity = nil
            clearWidgetData()
        }
    }

    private func syncToWidget(state: PomodoroActivityAttributes.ContentState, routineName: String) {
        appGroupDefaults?.set(state.remainingTime, forKey: "remainingTime")
        appGroupDefaults?.set(state.totalTime, forKey: "totalTime")
        appGroupDefaults?.set(state.phase.rawValue, forKey: "phase")
        appGroupDefaults?.set(state.currentRound, forKey: "currentRound")
        appGroupDefaults?.set(state.totalRounds, forKey: "totalRounds")
        appGroupDefaults?.set(state.isRunning, forKey: "isRunning")
        appGroupDefaults?.set(routineName, forKey: "routineName")

        WidgetCenter.shared.reloadAllTimelines()
    }

    private func clearWidgetData() {
        appGroupDefaults?.removeObject(forKey: "remainingTime")
        appGroupDefaults?.removeObject(forKey: "totalTime")
        appGroupDefaults?.removeObject(forKey: "phase")
        appGroupDefaults?.removeObject(forKey: "currentRound")
        appGroupDefaults?.removeObject(forKey: "totalRounds")
        appGroupDefaults?.removeObject(forKey: "isRunning")
        appGroupDefaults?.removeObject(forKey: "routineName")

        WidgetCenter.shared.reloadAllTimelines()
    }

    func syncTimerState(
        timeRemaining: TimeInterval,
        totalTime: TimeInterval,
        phase: TimerPhase,
        currentRound: Int,
        totalRounds: Int,
        isRunning: Bool,
        routineName: String
    ) {
        let state = PomodoroActivityAttributes.ContentState(
            remainingTime: timeRemaining,
            totalTime: totalTime,
            phase: phase,
            currentRound: currentRound,
            totalRounds: totalRounds,
            isRunning: isRunning
        )

        if currentActivity == nil && isRunning {
            startActivity(routineName: routineName, state: state)
        } else if currentActivity != nil {
            if !isRunning && phase == .work && timeRemaining == totalTime {
                endActivity()
            } else {
                updateActivity(state: state)
            }
        }

        syncToWidget(state: state, routineName: routineName)
    }
}
