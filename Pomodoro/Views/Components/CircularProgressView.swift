import SwiftUI

struct CircularProgressView: View {
    let progress: Double
    let lineWidth: CGFloat
    let color: Color

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    color.opacity(0.15),
                    lineWidth: lineWidth
                )

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: animatedProgress)
        }
        .onChange(of: progress) { _, newValue in
            animatedProgress = newValue
        }
        .onAppear {
            animatedProgress = progress
        }
    }
}

struct CircularProgressView_Previews: PreviewProvider {
    static var previews: some View {
        CircularProgressView(progress: 0.7, lineWidth: 20, color: .pomodoroRed)
            .frame(width: 200, height: 200)
            .padding()
    }
}
