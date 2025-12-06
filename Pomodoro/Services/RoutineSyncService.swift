import Foundation
import SwiftData
import Combine

@MainActor
class RoutineSyncService: ObservableObject {
    private let connectivityManager = WatchConnectivityManager.shared
    private var modelContext: ModelContext?
    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: .routinesRequested)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.sendRoutinesToWatch()
            }
            .store(in: &cancellables)
    }

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        sendRoutinesToWatch()
    }

    func sendRoutinesToWatch() {
        guard let modelContext = modelContext else { return }

        let descriptor = FetchDescriptor<Routine>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])

        do {
            let routines = try modelContext.fetch(descriptor)
            let transfers = routines.map { routine in
                RoutineTransfer(
                    id: routine.id.uuidString,
                    name: routine.name,
                    workDuration: routine.workDuration,
                    shortBreakDuration: routine.shortBreakDuration,
                    longBreakDuration: routine.longBreakDuration,
                    roundsBeforeLongBreak: routine.roundsBeforeLongBreak,
                    totalRounds: routine.totalRounds
                )
            }
            connectivityManager.sendRoutines(transfers)
        } catch {
            print("Failed to fetch routines: \(error)")
        }
    }
}
