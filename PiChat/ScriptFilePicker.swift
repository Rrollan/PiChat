import Foundation

enum ScriptFilePicker {
    static func pickFiles(prompt: String = "Attach Files") -> [URL] {
        let escapedPrompt = prompt.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        set output to ""
        try
            set selectedFiles to choose file with prompt "\(escapedPrompt)" with multiple selections allowed
            repeat with f in selectedFiles
                set output to output & POSIX path of f & linefeed
            end repeat
            return output
        on error number -128
            return ""
        end try
        """

        guard let output = runAppleScript(script) else { return [] }
        return output
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { URL(fileURLWithPath: $0) }
    }

    static func pickFolder(prompt: String = "Select Project Folder") -> URL? {
        let escapedPrompt = prompt.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        try
            return POSIX path of (choose folder with prompt "\(escapedPrompt)")
        on error number -128
            return ""
        end try
        """

        guard let output = runAppleScript(script)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !output.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: output)
    }

    private static func runAppleScript(_ script: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = outPipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = outPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(decoding: data, as: UTF8.self)
            return process.terminationStatus == 0 ? output : nil
        } catch {
            return nil
        }
    }
}
