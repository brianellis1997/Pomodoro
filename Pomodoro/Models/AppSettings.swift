import Foundation
import SwiftData

@Model
final class AppSettings {
    var id: UUID

    var workEndSound: String
    var breakEndSound: String
    var tickingEnabled: Bool
    var vibrationEnabled: Bool

    var focusModeEnabled: Bool
    var autoStartBreaks: Bool
    var autoStartWork: Bool

    var notificationsEnabled: Bool
    var calendarIntegrationEnabled: Bool

    var spotifyEnabled: Bool
    var appleMusicEnabled: Bool
    var studyPlaylistId: String?
    var breakPlaylistId: String?

    init(
        id: UUID = UUID(),
        workEndSound: String = "bell",
        breakEndSound: String = "chime",
        tickingEnabled: Bool = false,
        vibrationEnabled: Bool = true,
        focusModeEnabled: Bool = false,
        autoStartBreaks: Bool = false,
        autoStartWork: Bool = false,
        notificationsEnabled: Bool = true,
        calendarIntegrationEnabled: Bool = false,
        spotifyEnabled: Bool = false,
        appleMusicEnabled: Bool = false,
        studyPlaylistId: String? = nil,
        breakPlaylistId: String? = nil
    ) {
        self.id = id
        self.workEndSound = workEndSound
        self.breakEndSound = breakEndSound
        self.tickingEnabled = tickingEnabled
        self.vibrationEnabled = vibrationEnabled
        self.focusModeEnabled = focusModeEnabled
        self.autoStartBreaks = autoStartBreaks
        self.autoStartWork = autoStartWork
        self.notificationsEnabled = notificationsEnabled
        self.calendarIntegrationEnabled = calendarIntegrationEnabled
        self.spotifyEnabled = spotifyEnabled
        self.appleMusicEnabled = appleMusicEnabled
        self.studyPlaylistId = studyPlaylistId
        self.breakPlaylistId = breakPlaylistId
    }

    static let availableSounds: [String] = [
        "bell",
        "chime",
        "gong",
        "ding",
        "notification",
        "success",
        "gentle",
        "alarm",
        "none"
    ]
}
