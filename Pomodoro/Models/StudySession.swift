import Foundation
import SwiftData

@Model
final class StudySession {
    var id: UUID
    var routineName: String
    var durationMinutes: Int
    var pointsEarned: Int
    var completedAt: Date
    var wasFullSession: Bool

    init(
        id: UUID = UUID(),
        routineName: String,
        durationMinutes: Int,
        pointsEarned: Int = 0,
        completedAt: Date = Date(),
        wasFullSession: Bool = true
    ) {
        self.id = id
        self.routineName = routineName
        self.durationMinutes = durationMinutes
        self.pointsEarned = pointsEarned
        self.completedAt = completedAt
        self.wasFullSession = wasFullSession
    }
}
