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
    var tagsData: String

    var tags: [String] {
        get {
            guard !tagsData.isEmpty else { return [] }
            return tagsData.components(separatedBy: ",")
        }
        set {
            tagsData = newValue.joined(separator: ",")
        }
    }

    init(
        id: UUID = UUID(),
        routineName: String,
        durationMinutes: Int,
        pointsEarned: Int = 0,
        completedAt: Date = Date(),
        wasFullSession: Bool = true,
        tags: [String] = []
    ) {
        self.id = id
        self.routineName = routineName
        self.durationMinutes = durationMinutes
        self.pointsEarned = pointsEarned
        self.completedAt = completedAt
        self.wasFullSession = wasFullSession
        self.tagsData = tags.joined(separator: ",")
    }
}
