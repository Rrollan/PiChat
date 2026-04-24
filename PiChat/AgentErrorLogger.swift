import Foundation

enum AgentErrorLogger {
    private static let dateFormatter: ISO8601DateFormatter = {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt
    }()

    private static var logFileURL: URL {
        let logsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/PiChat", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        return logsDir.appendingPathComponent("agent-errors.log")
    }

    static func log(_ message: String, context: String) {
        let line = "[\(dateFormatter.string(from: Date()))] [\(context)] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        let url = logFileURL
        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
                try? handle.close()
                return
            }
        }

        try? data.write(to: url, options: .atomic)
    }
}
