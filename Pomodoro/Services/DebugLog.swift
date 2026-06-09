import Foundation

final class DebugLog {
    static let shared = DebugLog()

    private let key = "debugLog"
    private let maxLines = 300
    private let defaults = UserDefaults(suiteName: "group.com.bdogellis.pomodoro.qillc")
    private let queue = DispatchQueue(label: "com.bdogellis.pomodoro.debuglog")
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private init() {}

    func log(_ message: String) {
        let timestamp = formatter.string(from: Date())
        let line = "\(timestamp) \(message)"
        print(line)
        queue.async { [weak self] in
            guard let self else { return }
            let existing = self.defaults?.string(forKey: self.key) ?? ""
            var lines = existing.isEmpty ? [] : existing.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            lines.append(line)
            if lines.count > self.maxLines {
                lines = Array(lines.suffix(self.maxLines))
            }
            self.defaults?.set(lines.joined(separator: "\n"), forKey: self.key)
        }
    }

    func getAll() -> String {
        return defaults?.string(forKey: key) ?? ""
    }

    func clear() {
        queue.async { [weak self] in
            self?.defaults?.removeObject(forKey: self?.key ?? "")
        }
    }
}
