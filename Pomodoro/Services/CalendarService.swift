import Foundation
import EventKit
import UserNotifications

@MainActor
class CalendarService: ObservableObject {
    static let shared = CalendarService()

    private let eventStore = EKEventStore()
    @Published var isAuthorized = false
    @Published var scheduledSessions: [ScheduledPomodoroSession] = []

    private let defaults = UserDefaults.standard
    private let sessionsKey = "scheduledPomodoroSessions"

    private init() {
        checkAuthorization()
        loadSessions()
    }

    func checkAuthorization() {
        let status = EKEventStore.authorizationStatus(for: .event)
        isAuthorized = status == .fullAccess || status == .authorized
    }

    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            await MainActor.run {
                isAuthorized = granted
            }
            return granted
        } catch {
            return false
        }
    }

    func createSession(
        routineName: String,
        routineConfig: RoutineConfiguration,
        date: Date,
        repeatPattern: RepeatPattern
    ) async -> Bool {
        if !isAuthorized {
            let granted = await requestAccess()
            if !granted { return false }
        }

        guard let calendar = eventStore.defaultCalendarForNewEvents ?? eventStore.calendars(for: .event).first else {
            return false
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = "Pomodoro: \(routineName)"
        event.startDate = date
        event.endDate = date.addingTimeInterval(TimeInterval(routineConfig.totalDurationMinutes * 60))
        event.calendar = calendar
        event.notes = "Routine: \(routineName)\nWork: \(routineConfig.workDuration)min\nBreak: \(routineConfig.shortBreakDuration)min\nRounds: \(routineConfig.totalRounds)"

        event.addAlarm(EKAlarm(relativeOffset: -60))
        event.addAlarm(EKAlarm(relativeOffset: 0))

        if repeatPattern != .none {
            let rule = createRecurrenceRule(for: repeatPattern)
            event.recurrenceRules = [rule]
        }

        do {
            try eventStore.save(event, span: .thisEvent)

            let session = ScheduledPomodoroSession(
                id: UUID(),
                eventIdentifier: event.eventIdentifier,
                routineName: routineName,
                routineConfig: routineConfig,
                scheduledDate: date,
                repeatPattern: repeatPattern
            )

            scheduledSessions.append(session)
            saveSessions()

            scheduleNotification(for: session)

            return true
        } catch {
            return false
        }
    }

    func deleteSession(_ session: ScheduledPomodoroSession) {
        if let eventIdentifier = session.eventIdentifier,
           let event = eventStore.event(withIdentifier: eventIdentifier) {
            try? eventStore.remove(event, span: .thisEvent)
        }

        scheduledSessions.removeAll { $0.id == session.id }
        saveSessions()

        cancelNotification(for: session)
    }

    func fetchUpcomingSessions() {
        guard isAuthorized else { return }

        let calendars = eventStore.calendars(for: .event)
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate)!

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        let events = eventStore.events(matching: predicate)

        let pomodoroEvents = events.filter { $0.title?.starts(with: "Pomodoro:") == true }

        for event in pomodoroEvents {
            if !scheduledSessions.contains(where: { $0.eventIdentifier == event.eventIdentifier }) {
                let session = ScheduledPomodoroSession(
                    id: UUID(),
                    eventIdentifier: event.eventIdentifier,
                    routineName: event.title?.replacingOccurrences(of: "Pomodoro: ", with: "") ?? "Unknown",
                    routineConfig: .classic,
                    scheduledDate: event.startDate,
                    repeatPattern: .none
                )
                scheduledSessions.append(session)
            }
        }

        scheduledSessions.sort { $0.scheduledDate < $1.scheduledDate }
        saveSessions()
    }

    private func createRecurrenceRule(for pattern: RepeatPattern) -> EKRecurrenceRule {
        switch pattern {
        case .none:
            return EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: EKRecurrenceEnd(occurrenceCount: 1))
        case .daily:
            return EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
        case .weekdays:
            let weekdays = [EKRecurrenceDayOfWeek(.monday),
                           EKRecurrenceDayOfWeek(.tuesday),
                           EKRecurrenceDayOfWeek(.wednesday),
                           EKRecurrenceDayOfWeek(.thursday),
                           EKRecurrenceDayOfWeek(.friday)]
            return EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, daysOfTheWeek: weekdays, daysOfTheMonth: nil, monthsOfTheYear: nil, weeksOfTheYear: nil, daysOfTheYear: nil, setPositions: nil, end: nil)
        case .weekly:
            return EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
        }
    }

    private func scheduleNotification(for session: ScheduledPomodoroSession) {
        let content = UNMutableNotificationContent()
        content.title = "Pomodoro Session Starting"
        content.body = "Your \(session.routineName) session is about to begin!"
        content.sound = .default
        content.userInfo = ["sessionId": session.id.uuidString, "routineName": session.routineName]

        let triggerDate = session.scheduledDate
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "pomodoro-session-\(session.id.uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)

        let reminderContent = UNMutableNotificationContent()
        reminderContent.title = "Pomodoro Session in 5 Minutes"
        reminderContent.body = "Your \(session.routineName) session starts soon!"
        reminderContent.sound = .default

        if let reminderDate = Calendar.current.date(byAdding: .minute, value: -5, to: triggerDate) {
            let reminderComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
            let reminderTrigger = UNCalendarNotificationTrigger(dateMatching: reminderComponents, repeats: false)

            let reminderRequest = UNNotificationRequest(
                identifier: "pomodoro-reminder-\(session.id.uuidString)",
                content: reminderContent,
                trigger: reminderTrigger
            )

            UNUserNotificationCenter.current().add(reminderRequest)
        }
    }

    private func cancelNotification(for session: ScheduledPomodoroSession) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "pomodoro-session-\(session.id.uuidString)",
            "pomodoro-reminder-\(session.id.uuidString)"
        ])
    }

    private func saveSessions() {
        if let encoded = try? JSONEncoder().encode(scheduledSessions) {
            defaults.set(encoded, forKey: sessionsKey)
        }
    }

    private func loadSessions() {
        if let data = defaults.data(forKey: sessionsKey),
           let decoded = try? JSONDecoder().decode([ScheduledPomodoroSession].self, from: data) {
            scheduledSessions = decoded.filter { $0.scheduledDate > Date() }
            saveSessions()
        }
    }
}

struct ScheduledPomodoroSession: Identifiable, Codable {
    let id: UUID
    let eventIdentifier: String?
    let routineName: String
    let routineConfig: RoutineConfiguration
    let scheduledDate: Date
    let repeatPattern: RepeatPattern
}

enum RepeatPattern: String, Codable, CaseIterable {
    case none = "Never"
    case daily = "Daily"
    case weekdays = "Weekdays"
    case weekly = "Weekly"
}

extension RoutineConfiguration {
    var totalDurationMinutes: Int {
        let workTime = workDuration * totalRounds
        let shortBreaks = shortBreakDuration * (totalRounds - 1)
        let longBreak = longBreakDuration
        return workTime + shortBreaks + longBreak
    }
}
