import Foundation
import SwiftData

@Model
final class TimerSession {
    var id: UUID
    var routineName: String
    var duration: Int
    var phase: String
    var completedAt: Date
    var wasCompleted: Bool

    init(
        id: UUID = UUID(),
        routineName: String,
        duration: Int,
        phase: String,
        completedAt: Date = Date(),
        wasCompleted: Bool = true
    ) {
        self.id = id
        self.routineName = routineName
        self.duration = duration
        self.phase = phase
        self.completedAt = completedAt
        self.wasCompleted = wasCompleted
    }
}
