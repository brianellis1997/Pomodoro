import Foundation

struct RoutineConfiguration: Codable, Equatable {
    var name: String
    var workDuration: Int
    var shortBreakDuration: Int
    var longBreakDuration: Int
    var roundsBeforeLongBreak: Int
    var totalRounds: Int

    init(
        name: String = "Classic Pomodoro",
        workDuration: Int = 25,
        shortBreakDuration: Int = 5,
        longBreakDuration: Int = 20,
        roundsBeforeLongBreak: Int = 4,
        totalRounds: Int = 4
    ) {
        self.name = name
        self.workDuration = workDuration
        self.shortBreakDuration = shortBreakDuration
        self.longBreakDuration = longBreakDuration
        self.roundsBeforeLongBreak = roundsBeforeLongBreak
        self.totalRounds = totalRounds
    }

    static let classicPomodoro = RoutineConfiguration()

    static let deepWork = RoutineConfiguration(
        name: "Deep Work",
        workDuration: 50,
        shortBreakDuration: 10,
        longBreakDuration: 30,
        roundsBeforeLongBreak: 3,
        totalRounds: 3
    )

    static let shortSprint = RoutineConfiguration(
        name: "Short Sprint",
        workDuration: 15,
        shortBreakDuration: 3,
        longBreakDuration: 10,
        roundsBeforeLongBreak: 4,
        totalRounds: 8
    )

    static let presets: [RoutineConfiguration] = [
        .classicPomodoro,
        .deepWork,
        .shortSprint
    ]
}
