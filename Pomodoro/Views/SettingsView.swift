import SwiftUI
import SwiftData
import UserNotifications
import EventKit

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
                NavigationLink {
                    SpotifyPlaylistInputView(
                        title: "Study Playlist",
                        playlistUri: Binding(
                            get: { settings.spotifyStudyPlaylistUri },
                            set: { newValue in
                                settings.spotifyStudyPlaylistUri = newValue
                                try? modelContext.save()
                            }
                        )
                    )
                } label: {
                    HStack {
                        Text("Study Playlist")
                        Spacer()
                        Text(settings.spotifyStudyPlaylistUri != nil ? "Set" : "None")
                            .foregroundColor(.secondary)
                    }
                }

                NavigationLink {
                    SpotifyPlaylistInputView(
                        title: "Break Playlist",
                        playlistUri: Binding(
                            get: { settings.spotifyBreakPlaylistUri },
                            set: { newValue in
                                settings.spotifyBreakPlaylistUri = newValue
                                try? modelContext.save()
                            }
                        )
                    )
                } label: {
                    HStack {
                        Text("Break Playlist")
                        Spacer()
                        Text(settings.spotifyBreakPlaylistUri != nil ? "Set" : "None")
                            .foregroundColor(.secondary)
                    }
                }

                if !SpotifyService.shared.isSpotifyInstalled {
                    Text("Spotify app not installed")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        } header: {
            Label("Music", systemImage: "music.note")
        } footer: {
            Text("Save your playlists here for quick access. Open them manually before starting your session.")
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
        Task {
            let granted = await CalendarService.shared.requestAccess()
            if !granted {
                await MainActor.run {
                    settings.calendarIntegrationEnabled = false
                    try? modelContext.save()
                }
            }
        }
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
    @StateObject private var calendarService = CalendarService.shared
    @State private var showingAddSheet = false

    var body: some View {
        List {
            if calendarService.scheduledSessions.isEmpty {
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
                .listRowBackground(Color.clear)
            } else {
                ForEach(calendarService.scheduledSessions) { session in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.routineName)
                            .fontWeight(.medium)
                        HStack {
                            Text(session.scheduledDate, style: .date)
                            Text("at")
                            Text(session.scheduledDate, style: .time)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)

                        if session.repeatPattern != .none {
                            Text("Repeats: \(session.repeatPattern.rawValue)")
                                .font(.caption2)
                                .foregroundColor(.pomodoroBlue)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let session = calendarService.scheduledSessions[index]
                        calendarService.deleteSession(session)
                    }
                }
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
            AddScheduledSessionView()
        }
        .onAppear {
            calendarService.fetchUpcomingSessions()
        }
    }
}

struct AddScheduledSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Routine.createdAt, order: .reverse) private var customRoutines: [Routine]
    @State private var selectedRoutine: RoutineConfiguration = .classic
    @State private var date = Date().addingTimeInterval(3600)
    @State private var repeatPattern: RepeatPattern = .none
    @State private var isCreating = false
    @State private var showError = false

    var body: some View {
        NavigationView {
            Form {
                Section("Routine") {
                    Picker("Select Routine", selection: $selectedRoutine) {
                        ForEach(RoutineConfiguration.presets, id: \.name) { preset in
                            Text(preset.name).tag(preset)
                        }
                        ForEach(customRoutines) { routine in
                            Text(routine.name).tag(routine.configuration)
                        }
                    }
                    .pickerStyle(.menu)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Duration: ~\(selectedRoutine.totalDurationMinutes) minutes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(selectedRoutine.totalRounds) rounds of \(selectedRoutine.workDuration)min work")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Schedule") {
                    DatePicker("Date & Time", selection: $date, in: Date()...)
                }

                Section("Repeat") {
                    Picker("Frequency", selection: $repeatPattern) {
                        ForEach(RepeatPattern.allCases, id: \.self) { pattern in
                            Text(pattern.rawValue).tag(pattern)
                        }
                    }
                    .pickerStyle(.menu)
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
                        createSession()
                    }
                    .disabled(isCreating)
                }
            }
            .alert("Failed to Create Event", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text("Could not add the session to your calendar. Please check your calendar permissions.")
            }
        }
    }

    private func createSession() {
        isCreating = true
        Task {
            let success = await CalendarService.shared.createSession(
                routineName: selectedRoutine.name,
                routineConfig: selectedRoutine,
                date: date,
                repeatPattern: repeatPattern
            )

            await MainActor.run {
                isCreating = false
                if success {
                    dismiss()
                } else {
                    showError = true
                }
            }
        }
    }
}

struct SpotifyPlaylistInputView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @Binding var playlistUri: String?
    @State private var inputText: String = ""
    @State private var showingHelp = false

    var body: some View {
        Form {
            Section {
                TextField("Playlist link or URI", text: $inputText)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                if !inputText.isEmpty {
                    Button("Test in Spotify") {
                        SpotifyService.shared.openPlaylist(inputText)
                    }
                }
            } header: {
                Text("Spotify Playlist")
            } footer: {
                Text("Paste a Spotify playlist link or URI")
            }

            Section {
                Button {
                    showingHelp = true
                } label: {
                    Label("How to get a playlist link", systemImage: "questionmark.circle")
                }
            }

            Section {
                Button("Save") {
                    playlistUri = inputText.isEmpty ? nil : inputText
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.pomodoroRed)

                if playlistUri != nil {
                    Button("Remove Playlist") {
                        playlistUri = nil
                        inputText = ""
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.red)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            inputText = playlistUri ?? ""
        }
        .alert("How to get a Spotify playlist link", isPresented: $showingHelp) {
            Button("OK") {}
        } message: {
            Text("1. Open Spotify\n2. Go to a playlist\n3. Tap ••• (more)\n4. Tap 'Share'\n5. Tap 'Copy link'\n6. Paste it here")
        }
    }
}
