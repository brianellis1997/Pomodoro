import SwiftUI

struct CircularProgressView: View {
    let progress: Double
    let lineWidth: CGFloat
    let color: Color
    var animated: Bool = true

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    color.opacity(0.15),
                    lineWidth: lineWidth
                )

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
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
