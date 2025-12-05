import SwiftUI

extension Color {
    static let pomodoroRed = Color(red: 0.91, green: 0.30, blue: 0.24)
    static let pomodoroGreen = Color(red: 0.18, green: 0.80, blue: 0.44)
    static let pomodoroBlue = Color(red: 0.20, green: 0.60, blue: 0.86)
    static let pomodoroOrange = Color(red: 0.95, green: 0.61, blue: 0.07)

    #if os(iOS)
    static let backgroundPrimary = Color(.systemBackground)
    static let backgroundSecondary = Color(.secondarySystemBackground)
    #else
    static let backgroundPrimary = Color.black
    static let backgroundSecondary = Color(white: 0.1)
    #endif
}

extension ShapeStyle where Self == Color {
    static var pomodoroRed: Color { Color.pomodoroRed }
    static var pomodoroGreen: Color { Color.pomodoroGreen }
    static var pomodoroBlue: Color { Color.pomodoroBlue }
    static var pomodoroOrange: Color { Color.pomodoroOrange }
}
