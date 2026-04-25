import Foundation

struct NativeMessagingInstallResult {
    let manifestPath: String
    let hostPath: String
    let allowedOrigin: String
}

enum NativeMessagingInstallerError: LocalizedError {
    case invalidExtensionId(String)
    case missingBundledHost

    var errorDescription: String? {
        switch self {
        case .invalidExtensionId(let id):
            return "Invalid Browspi Browser UID or Chrome extension id: \(id). Paste the digit-only UID shown by Browspi Connect, or the 32-character Chrome extension id."
        case .missingBundledHost:
            return "Bundled Browspi native host script was not found in PiChat resources."
        }
    }
}

struct NativeMessagingInstaller {
    static let hostName = "com.browspi.pi_bridge"

    static var chromeManifestPath: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent("Library/Application Support/Google/Chrome/NativeMessagingHosts", isDirectory: true)
            .appendingPathComponent("\(hostName).json")
    }

    static var applicationSupportHostDirectory: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent("Library/Application Support/PiChat/NativeHost", isDirectory: true)
    }

    static var installedHostScriptPath: URL {
        applicationSupportHostDirectory.appendingPathComponent("browspi-native-host.mjs")
    }

    static var installedHostPath: URL {
        applicationSupportHostDirectory.appendingPathComponent("browspi-native-host")
    }

    static func normalizeExtensionId(_ raw: String) throws -> String {
        let trimmed = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .lowercased()

        let extensionIdPattern = "^[a-p]{32}$"
        if trimmed.range(of: extensionIdPattern, options: .regularExpression) != nil {
            return trimmed
        }

        // Browser UID: reversible digit-only encoding of Chrome extension id.
        // a=00, b=01, ... p=15. This lets users copy digits instead of a-p letters.
        let uidPattern = "^[0-9]{64}$"
        if trimmed.range(of: uidPattern, options: .regularExpression) != nil {
            var output = ""
            var index = trimmed.startIndex
            while index < trimmed.endIndex {
                let next = trimmed.index(index, offsetBy: 2)
                let pair = String(trimmed[index..<next])
                guard let value = Int(pair), value >= 0, value <= 15,
                      let scalar = UnicodeScalar(97 + value) else {
                    throw NativeMessagingInstallerError.invalidExtensionId(raw)
                }
                output.append(Character(scalar))
                index = next
            }
            return output
        }

        throw NativeMessagingInstallerError.invalidExtensionId(raw)
    }

    static func isInstalled(extensionId: String) -> Bool {
        guard let normalized = try? normalizeExtensionId(extensionId) else { return false }
        guard let data = try? Data(contentsOf: chromeManifestPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        let path = json["path"] as? String
        let origins = json["allowed_origins"] as? [String] ?? []
        return path == installedHostPath.path && origins.contains("chrome-extension://\(normalized)/")
    }

    @discardableResult
    static func install(extensionId rawExtensionId: String) throws -> NativeMessagingInstallResult {
        let extensionId = try normalizeExtensionId(rawExtensionId)
        let fm = FileManager.default

        guard let bundledHostScript = Bundle.main.url(forResource: "browspi-native-host", withExtension: "mjs"),
              let bundledHostWrapper = Bundle.main.url(forResource: "browspi-native-host", withExtension: nil) else {
            throw NativeMessagingInstallerError.missingBundledHost
        }

        try fm.createDirectory(at: applicationSupportHostDirectory, withIntermediateDirectories: true)
        for url in [installedHostScriptPath, installedHostPath] where fm.fileExists(atPath: url.path) {
            try fm.removeItem(at: url)
        }
        try fm.copyItem(at: bundledHostScript, to: installedHostScriptPath)
        try fm.copyItem(at: bundledHostWrapper, to: installedHostPath)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: installedHostScriptPath.path)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: installedHostPath.path)

        let manifestDir = chromeManifestPath.deletingLastPathComponent()
        try fm.createDirectory(at: manifestDir, withIntermediateDirectories: true)

        let allowedOrigin = "chrome-extension://\(extensionId)/"
        let manifest: [String: Any] = [
            "name": hostName,
            "description": "Browspi native Pi bridge installed by PiChat",
            "path": installedHostPath.path,
            "type": "stdio",
            "allowed_origins": [allowedOrigin]
        ]

        let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: chromeManifestPath, options: [.atomic])

        return NativeMessagingInstallResult(
            manifestPath: chromeManifestPath.path,
            hostPath: installedHostPath.path,
            allowedOrigin: allowedOrigin
        )
    }
}
