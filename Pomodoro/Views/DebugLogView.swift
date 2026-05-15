import SwiftUI
import UIKit

struct DebugLogView: View {
    @State private var logText: String = ""
    @State private var showShareSheet = false
    @State private var copiedFeedback = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.caption)
                }

                Button {
                    UIPasteboard.general.string = logText
                    copiedFeedback = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copiedFeedback = false
                    }
                } label: {
                    Label(copiedFeedback ? "Copied!" : "Copy All", systemImage: copiedFeedback ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                }

                Button {
                    showShareSheet = true
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.caption)
                }

                Spacer()

                Button(role: .destructive) {
                    DebugLog.shared.clear()
                    logText = ""
                } label: {
                    Label("Clear", systemImage: "trash")
                        .font(.caption)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))

            ScrollViewReader { proxy in
                ScrollView {
                    Text(logText.isEmpty ? "No logs yet. Reproduce the bug, then come back here." : logText)
                        .font(.system(size: 10, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .id("logEnd")
                }
                .onAppear {
                    if !logText.isEmpty {
                        proxy.scrollTo("logEnd", anchor: .bottom)
                    }
                }
            }
        }
        .navigationTitle("Debug Log")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refresh() }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [logText.isEmpty ? "(empty)" : logText])
        }
    }

    private func refresh() {
        logText = DebugLog.shared.getAll()
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
