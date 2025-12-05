import Foundation
import SwiftData

@Model
final class Routine {
    var id: UUID
    var name: String
    var workDuration: Int
    var shortBreakDuration: Int
    var longBreakDuration: Int
    var roundsBeforeLongBreak: Int
    var totalRounds: Int
    var isDefault: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String = "Classic Pomodoro",
        workDuration: Int = 25,
        shortBreakDuration: Int = 5,
        longBreakDuration: Int = 20,
        roundsBeforeLongBreak: Int = 4,
        totalRounds: Int = 4,
        isDefault: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.workDuration = workDuration
        self.shortBreakDuration = shortBreakDuration
        self.longBreakDuration = longBreakDuration
        self.roundsBeforeLongBreak = roundsBeforeLongBreak
        self.totalRounds = totalRounds
        self.isDefault = isDefault
        self.createdAt = createdAt
    }

    static var classicPomodoro: Routine {
        Routine(
            name: "Classic Pomodoro",
            workDuration: 25,
            shortBreakDuration: 5,
            longBreakDuration: 20,
            roundsBeforeLongBreak: 4,
            totalRounds: 4,
            isDefault: true
        )
    }

    static var deepWork: Routine {
        Routine(
            name: "Deep Work",
            workDuration: 50,
            shortBreakDuration: 10,
            longBreakDuration: 30,
            roundsBeforeLongBreak: 3,
            totalRounds: 3
        )
    }

    static var shortSprint: Routine {
        Routine(
            name: "Short Sprint",
            workDuration: 15,
            shortBreakDuration: 3,
            longBreakDuration: 10,
            roundsBeforeLongBreak: 4,
            totalRounds: 8
        )
    }

    var configuration: RoutineConfiguration {
        RoutineConfiguration(
            name: name,
            workDuration: workDuration,
            shortBreakDuration: shortBreakDuration,
            longBreakDuration: longBreakDuration,
            roundsBeforeLongBreak: roundsBeforeLongBreak,
            totalRounds: totalRounds
        )
    }
}
