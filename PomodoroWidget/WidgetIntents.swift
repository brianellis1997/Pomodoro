import AppIntents
import WidgetKit

struct ToggleTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Timer"
    static var description = IntentDescription("Starts or pauses the Pomodoro timer")

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.bdogellis.pomodoro")
        let isRunning = defaults?.bool(forKey: "isRunning") ?? false

        if !isRunning {
            let remainingTime = defaults?.double(forKey: "remainingTime") ?? (25 * 60)
            let endTime = Date().addingTimeInterval(remainingTime)
            defaults?.set(endTime.timeIntervalSince1970, forKey: "endTime")
        } else {
            defaults?.removeObject(forKey: "endTime")
        }

        defaults?.set(!isRunning, forKey: "isRunning")
        defaults?.set(true, forKey: "pendingAction")
        defaults?.set(isRunning ? "pause" : "start", forKey: "actionType")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct ResetTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Reset Timer"
    static var description = IntentDescription("Resets the Pomodoro timer")

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.bdogellis.pomodoro")
        defaults?.set(false, forKey: "isRunning")
        defaults?.removeObject(forKey: "endTime")
        defaults?.set(true, forKey: "pendingAction")
        defaults?.set("reset", forKey: "actionType")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct SkipPhaseIntent: AppIntent {
    static var title: LocalizedStringResource = "Skip Phase"
    static var description = IntentDescription("Skips to the next phase")

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.bdogellis.pomodoro")
        defaults?.set(true, forKey: "pendingAction")
        defaults?.set("skip", forKey: "actionType")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
