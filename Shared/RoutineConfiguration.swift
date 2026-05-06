import Foundation

struct RoutineConfiguration: Codable, Equatable, Hashable {
    var name: String
    var workDuration: Int
    var shortBreakDuration: Int
    var longBreakDuration: Int
    var roundsBeforeLongBreak: Int
    var totalRounds: Int
    var steps: [SessionStep]

    init(
        name: String = "Classic Pomodoro",
        workDuration: Int = 25,
        shortBreakDuration: Int = 5,
        longBreakDuration: Int = 20,
        roundsBeforeLongBreak: Int = 4,
        totalRounds: Int = 4,
        steps: [SessionStep] = []
    ) {
        self.name = name
        self.workDuration = workDuration
        self.shortBreakDuration = shortBreakDuration
        self.longBreakDuration = longBreakDuration
        self.roundsBeforeLongBreak = roundsBeforeLongBreak
        self.totalRounds = totalRounds
        if steps.isEmpty {
            self.steps = [SessionStep].expandLegacy(
                work: workDuration,
                shortBreak: shortBreakDuration,
                longBreak: longBreakDuration,
                longBreakEvery: roundsBeforeLongBreak,
                rounds: totalRounds
            )
        } else {
            self.steps = steps
        }
    }

    private enum CodingKeys: String, CodingKey {
        case name, workDuration, shortBreakDuration, longBreakDuration
        case roundsBeforeLongBreak, totalRounds, steps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(String.self, forKey: .name)
        let work = try container.decode(Int.self, forKey: .workDuration)
        let shortBreak = try container.decode(Int.self, forKey: .shortBreakDuration)
        let longBreak = try container.decode(Int.self, forKey: .longBreakDuration)
        let longBreakEvery = try container.decode(Int.self, forKey: .roundsBeforeLongBreak)
        let rounds = try container.decode(Int.self, forKey: .totalRounds)
        let decodedSteps = try container.decodeIfPresent([SessionStep].self, forKey: .steps) ?? []

        self.init(
            name: name,
            workDuration: work,
            shortBreakDuration: shortBreak,
            longBreakDuration: longBreak,
            roundsBeforeLongBreak: longBreakEvery,
            totalRounds: rounds,
            steps: decodedSteps
        )
    }

    static let classicPomodoro = RoutineConfiguration()
    static let classic = classicPomodoro

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
