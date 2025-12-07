import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsArray: [AppSettings]
    @State private var showingCalendarPermission = false
    @State private var showingMusicPermission = false

    private var settings: AppSettings {
        if let existing = settingsArray.first {
            return existing
        }
        let newSettings = AppSettings()
        modelContext.insert(newSettings)
        try? modelContext.save()
        return newSettings
    }

    var body: some View {
        NavigationView {
            List {
                soundsSection
                timerBehaviorSection
                musicSection
                integrationsSection
                aboutSection
            }
            .navigationTitle("Settings")
        }
    }

    private var soundsSection: some View {
        Section {
            Picker("Work Complete Sound", selection: Binding(
                get: { settings.workEndSound },
                set: { newValue in
                    settings.workEndSound = newValue
                    try? modelContext.save()
                    playPreviewSound(newValue)
                }
            )) {
                ForEach(AppSettings.availableSounds, id: \.self) { sound in
                    Text(sound.capitalized).tag(sound)
                }
            }

            Picker("Break Complete Sound", selection: Binding(
                get: { settings.breakEndSound },
                set: { newValue in
                    settings.breakEndSound = newValue
                    try? modelContext.save()
                    playPreviewSound(newValue)
                }
            )) {
                ForEach(AppSettings.availableSounds, id: \.self) { sound in
                    Text(sound.capitalized).tag(sound)
                }
            }

            Toggle("Ticking Sound", isOn: Binding(
                get: { settings.tickingEnabled },
                set: { newValue in
                    settings.tickingEnabled = newValue
                    try? modelContext.save()
                }
            ))

            Toggle("Vibration", isOn: Binding(
                get: { settings.vibrationEnabled },
                set: { newValue in
                    settings.vibrationEnabled = newValue
                    try? modelContext.save()
                }
            ))
        } header: {
            Label("Sounds & Haptics", systemImage: "speaker.wave.2.fill")
        }
    }

    private var timerBehaviorSection: some View {
        Section {
            Toggle("Auto-start Breaks", isOn: Binding(
                get: { settings.autoStartBreaks },
                set: { newValue in
                    settings.autoStartBreaks = newValue
                    try? modelContext.save()
                }
            ))

            Toggle("Auto-start Work Sessions", isOn: Binding(
                get: { settings.autoStartWork },
                set: { newValue in
                    settings.autoStartWork = newValue
                    try? modelContext.save()
                }
            ))

            Toggle("Focus Mode (Guilt-based)", isOn: Binding(
                get: { settings.focusModeEnabled },
                set: { newValue in
                    settings.focusModeEnabled = newValue
                    try? modelContext.save()
                }
            ))

            if settings.focusModeEnabled {
                Text("Session will fail if you leave the app during focus time")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } header: {
            Label("Timer Behavior", systemImage: "timer")
        }
    }

    private var musicSection: some View {
        Section {
            Toggle("Apple Music", isOn: Binding(
                get: { settings.appleMusicEnabled },
                set: { newValue in
                    settings.appleMusicEnabled = newValue
                    if newValue {
                        requestMusicPermission()
                    }
                    try? modelContext.save()
                }
            ))

            if settings.appleMusicEnabled {
                NavigationLink {
                    PlaylistPickerView(
                        title: "Study Playlist",
                        selectedId: Binding(
                            get: { settings.studyPlaylistId },
                            set: { newValue in
                                settings.studyPlaylistId = newValue
                                try? modelContext.save()
                            }
                        )
                    )
                } label: {
                    HStack {
                        Text("Study Playlist")
                        Spacer()
                        Text(settings.studyPlaylistId ?? "None")
                            .foregroundColor(.secondary)
                    }
                }

                NavigationLink {
                    PlaylistPickerView(
                        title: "Break Playlist",
                        selectedId: Binding(
                            get: { settings.breakPlaylistId },
                            set: { newValue in
                                settings.breakPlaylistId = newValue
                                try? modelContext.save()
                            }
                        )
                    )
                } label: {
                    HStack {
                        Text("Break Playlist")
                        Spacer()
                        Text(settings.breakPlaylistId ?? "None")
                            .foregroundColor(.secondary)
                    }
                }
            }

            Toggle("Spotify", isOn: Binding(
                get: { settings.spotifyEnabled },
                set: { newValue in
                    settings.spotifyEnabled = newValue
                    try? modelContext.save()
                }
            ))

            if settings.spotifyEnabled {
                Text("Spotify integration requires the Spotify app")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } header: {
            Label("Music", systemImage: "music.note")
        } footer: {
            Text("Play music automatically during study or break sessions")
        }
    }

    private var integrationsSection: some View {
        Section {
            Toggle("Notifications", isOn: Binding(
                get: { settings.notificationsEnabled },
                set: { newValue in
                    settings.notificationsEnabled = newValue
                    if newValue {
                        requestNotificationPermission()
                    }
                    try? modelContext.save()
                }
            ))

            Toggle("Calendar Integration", isOn: Binding(
                get: { settings.calendarIntegrationEnabled },
                set: { newValue in
                    settings.calendarIntegrationEnabled = newValue
                    if newValue {
                        requestCalendarPermission()
                    }
                    try? modelContext.save()
                }
            ))

            if settings.calendarIntegrationEnabled {
                NavigationLink {
                    ScheduledSessionsView()
                } label: {
                    Text("Scheduled Sessions")
                }
            }
        } header: {
            Label("Integrations", systemImage: "link")
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }

            Link(destination: URL(string: "https://github.com/brianellis1997/Pomodoro")!) {
                HStack {
                    Text("Source Code")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Label("About", systemImage: "info.circle")
        }
    }

    private func playPreviewSound(_ sound: String) {
        // TODO: Implement sound preview using AVFoundation
    }

    private func requestMusicPermission() {
        // TODO: Implement MusicKit authorization
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func requestCalendarPermission() {
        // TODO: Implement EventKit authorization
    }
}

struct PlaylistPickerView: View {
    let title: String
    @Binding var selectedId: String?

    var body: some View {
        List {
            Button("None") {
                selectedId = nil
            }

            Section("Your Playlists") {
                Text("Connect Apple Music in Settings to see playlists")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .navigationTitle(title)
    }
}

struct ScheduledSessionsView: View {
    @State private var scheduledSessions: [ScheduledSession] = []
    @State private var showingAddSheet = false

    var body: some View {
        List {
            if scheduledSessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No scheduled sessions")
                        .font(.headline)
                    Text("Add sessions to your calendar that will automatically start the timer")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }

            ForEach(scheduledSessions) { session in
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.routineName)
                        .fontWeight(.medium)
                    Text(session.scheduledDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .onDelete { indexSet in
                scheduledSessions.remove(atOffsets: indexSet)
            }
        }
        .navigationTitle("Scheduled Sessions")
        .toolbar {
            Button {
                showingAddSheet = true
            } label: {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddScheduledSessionView { session in
                scheduledSessions.append(session)
            }
        }
    }
}

struct ScheduledSession: Identifiable {
    let id = UUID()
    let routineName: String
    let scheduledDate: Date
    let repeatPattern: RepeatPattern

    enum RepeatPattern: String, CaseIterable {
        case none = "Never"
        case daily = "Daily"
        case weekdays = "Weekdays"
        case weekly = "Weekly"
    }
}

struct AddScheduledSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Routine.createdAt, order: .reverse) private var customRoutines: [Routine]
    @State private var routineName = "Classic Pomodoro"
    @State private var date = Date()
    @State private var repeatPattern: ScheduledSession.RepeatPattern = .none

    let onSave: (ScheduledSession) -> Void

    var body: some View {
        NavigationView {
            Form {
                Picker("Routine", selection: $routineName) {
                    Section("Presets") {
                        ForEach(RoutineConfiguration.presets, id: \.name) { preset in
                            Text(preset.name).tag(preset.name)
                        }
                    }
                    if !customRoutines.isEmpty {
                        Section("Your Routines") {
                            ForEach(customRoutines) { routine in
                                Text(routine.name).tag(routine.name)
                            }
                        }
                    }
                }

                DatePicker("Date & Time", selection: $date)

                Picker("Repeat", selection: $repeatPattern) {
                    ForEach(ScheduledSession.RepeatPattern.allCases, id: \.self) { pattern in
                        Text(pattern.rawValue).tag(pattern)
                    }
                }
            }
            .navigationTitle("Schedule Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let session = ScheduledSession(
                            routineName: routineName,
                            scheduledDate: date,
                            repeatPattern: repeatPattern
                        )
                        onSave(session)
                        dismiss()
                    }
                }
            }
        }
    }
}
