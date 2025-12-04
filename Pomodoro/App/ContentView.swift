import SwiftUI

struct ContentView: View {
    @StateObject private var timerViewModel = TimerViewModel()

    var body: some View {
        TimerView(viewModel: timerViewModel)
    }
}

#Preview {
    ContentView()
}
