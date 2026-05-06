import Foundation

enum SessionKind: String, Codable, Hashable, CaseIterable {
    case focus
    case shortBreak
    case longBreak

    var defaultName: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak: return "Break"
        case .longBreak: return "Long Break"
        }
    }

    var defaultEmoji: String {
        switch self {
        case .focus: return "🍅"
        case .shortBreak: return "☕️"
        case .longBreak: return "🌴"
        }
    }
}

struct SessionStep: Codable, Identifiable, Hashable {
    var id: UUID
    var kind: SessionKind
    var durationMinutes: Int
    var label: String?

    init(id: UUID = UUID(), kind: SessionKind, durationMinutes: Int, label: String? = nil) {
        self.id = id
        self.kind = kind
        self.durationMinutes = durationMinutes
        self.label = label
    }

    func displayLabel(positionAmongKind: Int, totalOfKind: Int) -> String {
        if let label = label, !label.isEmpty {
            return label
        }
        guard totalOfKind > 1 else { return kind.defaultName }
        return "\(kind.defaultName) \(positionAmongKind)"
    }
}

extension Array where Element == SessionStep {
    func displayLabel(at index: Int) -> String {
        guard indices.contains(index) else { return "" }
        let step = self[index]
        let sameKind = enumerated().filter { $0.element.kind == step.kind }
        let totalOfKind = sameKind.count
        let positionAmongKind = (sameKind.firstIndex { $0.offset == index } ?? 0) + 1
        return step.displayLabel(positionAmongKind: positionAmongKind, totalOfKind: totalOfKind)
    }

    var totalMinutes: Int {
        reduce(0) { $0 + $1.durationMinutes }
    }

    static func expandLegacy(
        work: Int,
        shortBreak: Int,
        longBreak: Int,
        longBreakEvery: Int,
        rounds: Int
    ) -> [SessionStep] {
        var steps: [SessionStep] = []
        let safeLongBreakEvery = Swift.max(1, longBreakEvery)
        let safeRounds = Swift.max(1, rounds)
        for round in 1...safeRounds {
            steps.append(SessionStep(kind: .focus, durationMinutes: Swift.max(1, work)))
            if round == safeRounds { break }
            if round % safeLongBreakEvery == 0 {
                steps.append(SessionStep(kind: .longBreak, durationMinutes: Swift.max(1, longBreak)))
            } else {
                steps.append(SessionStep(kind: .shortBreak, durationMinutes: Swift.max(1, shortBreak)))
            }
        }
        return steps
    }
}

extension SessionKind {
    init(from phase: TimerPhase) {
        switch phase {
        case .work: self = .focus
        case .shortBreak: self = .shortBreak
        case .longBreak: self = .longBreak
        }
    }

    var asPhase: TimerPhase {
        switch self {
        case .focus: return .work
        case .shortBreak: return .shortBreak
        case .longBreak: return .longBreak
        }
    }
}
