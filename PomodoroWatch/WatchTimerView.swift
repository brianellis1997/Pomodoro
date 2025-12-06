import SwiftUI

struct WatchTimerView: View {
    @StateObject private var engine = TimerEngine()
    @State private var currentRoutineName = "Classic Pomodoro"
    @State private var showRoutinePicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 6) {
                Button {
                    showRoutinePicker = true
                } label: {
                    HStack(spacing: 2) {
                        Text(currentRoutineName)
                            .font(.caption2)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Text(engine.phaseDisplayName)
                    .font(.caption2)
                    .foregroundColor(phaseColor)
                    .textCase(.uppercase)

                ZStack {
                    Circle()
                        .stroke(phaseColor.opacity(0.2), lineWidth: 8)

                    Circle()
                        .trim(from: 0, to: engine.progress)
                        .stroke(phaseColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text(engine.formattedTime)
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.medium)
                            .monospacedDigit()

                        Text("Round \(engine.currentRound)/\(engine.totalRounds)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 8)

                HStack(spacing: 20) {
                    Button(action: engine.reset) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.body)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        if engine.state == .running {
                            engine.pause()
                        } else {
                            engine.start()
                        }
                    }) {
                        Image(systemName: engine.state == .running ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(phaseColor)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Button(action: engine.skip) {
                        Image(systemName: "forward.fill")
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
            .sheet(isPresented: $showRoutinePicker) {
                WatchRoutinePickerView(
                    selectedRoutineName: $currentRoutineName,
                    engine: engine
                )
            }
        }
    }

    private var phaseColor: Color {
        switch engine.phase {
        case .work:
            return .pomodoroRed
        case .shortBreak:
            return .pomodoroGreen
        case .longBreak:
            return .pomodoroBlue
        }
    }
}

struct WatchRoutinePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedRoutineName: String
    let engine: TimerEngine

    var body: some View {
        List {
            ForEach(RoutineConfiguration.presets, id: \.name) { preset in
                Button {
                    selectedRoutineName = preset.name
                    engine.configure(routine: preset)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.name)
                                .font(.caption)
                            Text("\(preset.workDuration)m / \(preset.shortBreakDuration)m")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if selectedRoutineName == preset.name {
                            Image(systemName: "checkmark")
                                .foregroundColor(.pomodoroRed)
                        }
                    }
                }
            }
        }
        .navigationTitle("Routines")
    }
}

#Preview {
    WatchTimerView()
}
