import Foundation
import SwiftData
import SwiftUI

@Model
final class SessionTag {
    var id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "FF6B6B",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
    }

    var color: Color {
        Color(hex: colorHex) ?? .pomodoroRed
    }

    static let defaultTags: [(name: String, colorHex: String)] = [
        ("Work", "FF6B6B"),
        ("Study", "4ECDC4"),
        ("Personal", "45B7D1"),
        ("Creative", "96CEB4"),
        ("Exercise", "FFEAA7"),
        ("Reading", "DDA0DD")
    ]
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }

    var hexString: String {
        guard let components = UIColor(self).cgColor.components else { return "FF6B6B" }
        let r = Int(components[0] * 255)
        let g = Int(components.count > 1 ? components[1] * 255 : components[0] * 255)
        let b = Int(components.count > 2 ? components[2] * 255 : components[0] * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
