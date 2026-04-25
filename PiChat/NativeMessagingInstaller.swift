import Foundation
import CryptoKit

struct NativeMessagingInstallResult {
    let manifestPath: String
    let hostPath: String
    let allowedOrigin: String
}

struct NativeMessagingManifestSnapshot {
    let exists: Bool
    let path: String
    let hostPath: String?
    let allowedOrigins: [String]
}

struct BrowserBridgeClientSnapshot: Codable {
    var extensionId: String?
    var version: String?
    var surface: String?
}

struct BrowserBridgePairingSnapshot: Codable {
    var pairingRequired: Bool
    var tokenHash: String?
    var paired: Bool
    var lastPairedAt: Double?
    var lastSeenAt: Double?
    var client: BrowserBridgeClientSnapshot?
    var updatedAt: Double?
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

    static var pairingConfigPath: URL {
        applicationSupportHostDirectory.appendingPathComponent("pairing.json")
    }

    static var installedBrowserToolsDirectory: URL {
        applicationSupportHostDirectory.appendingPathComponent("browser-tools", isDirectory: true)
    }

    static var installedBrowserToolsExtensionPath: URL {
        installedBrowserToolsDirectory.appendingPathComponent("index.ts")
    }

    static func generatePairingToken() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789")
        var generator = SystemRandomNumberGenerator()
        return String((0..<24).map { _ in alphabet.randomElement(using: &generator) ?? "X" })
    }

    static func pairingTokenHash(_ token: String) -> String {
        let digest = SHA256.hash(data: Data(token.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
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

    static func manifestSnapshot() -> NativeMessagingManifestSnapshot {
        guard let data = try? Data(contentsOf: chromeManifestPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return NativeMessagingManifestSnapshot(exists: false, path: chromeManifestPath.path, hostPath: nil, allowedOrigins: [])
        }
        return NativeMessagingManifestSnapshot(
            exists: true,
            path: chromeManifestPath.path,
            hostPath: json["path"] as? String,
            allowedOrigins: json["allowed_origins"] as? [String] ?? []
        )
    }

    static func isInstalled(extensionId: String) -> Bool {
        guard let normalized = try? normalizeExtensionId(extensionId) else { return false }
        let manifest = manifestSnapshot()
        return manifest.hostPath == installedHostPath.path && manifest.allowedOrigins.contains("chrome-extension://\(normalized)/")
    }

    static func readPairingSnapshot() -> BrowserBridgePairingSnapshot? {
        guard let data = try? Data(contentsOf: pairingConfigPath) else { return nil }
        return try? JSONDecoder().decode(BrowserBridgePairingSnapshot.self, from: data)
    }

    static func writePairingConfig(token: String, required: Bool = true) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: applicationSupportHostDirectory, withIntermediateDirectories: true)
        let tokenHash = pairingTokenHash(token)
        let existing = readPairingSnapshot()
        let sameToken = existing?.tokenHash == tokenHash
        let snapshot = BrowserBridgePairingSnapshot(
            pairingRequired: required,
            tokenHash: tokenHash,
            paired: sameToken ? (existing?.paired ?? false) : false,
            lastPairedAt: sameToken ? existing?.lastPairedAt : nil,
            lastSeenAt: sameToken ? existing?.lastSeenAt : nil,
            client: sameToken ? existing?.client : nil,
            updatedAt: Date().timeIntervalSince1970
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: pairingConfigPath, options: [.atomic])
    }

    static func writeTrustedOriginPairingConfig() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: applicationSupportHostDirectory, withIntermediateDirectories: true)
        let existing = readPairingSnapshot()
        let snapshot = BrowserBridgePairingSnapshot(
            pairingRequired: false,
            tokenHash: nil,
            paired: true,
            lastPairedAt: existing?.lastPairedAt,
            lastSeenAt: existing?.lastSeenAt,
            client: existing?.client,
            updatedAt: Date().timeIntervalSince1970
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: pairingConfigPath, options: [.atomic])
    }

    static func uninstall() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: chromeManifestPath.path) {
            try fm.removeItem(at: chromeManifestPath)
        }
        if fm.fileExists(atPath: pairingConfigPath.path) {
            try fm.removeItem(at: pairingConfigPath)
        }
    }

    @discardableResult
    static func install(extensionId rawExtensionId: String, pairingToken: String? = nil) throws -> NativeMessagingInstallResult {
        let extensionId = try normalizeExtensionId(rawExtensionId)
        let fm = FileManager.default

        guard let bundledHostScript = Bundle.main.url(forResource: "browspi-native-host", withExtension: "mjs"),
              let bundledHostWrapper = Bundle.main.url(forResource: "browspi-native-host", withExtension: nil) else {
            throw NativeMessagingInstallerError.missingBundledHost
        }
        let bundledBrowserTools = Bundle.main.url(forResource: "index", withExtension: "ts", subdirectory: "browser-tools")

        try fm.createDirectory(at: applicationSupportHostDirectory, withIntermediateDirectories: true)
        for url in [installedHostScriptPath, installedHostPath] where fm.fileExists(atPath: url.path) {
            try fm.removeItem(at: url)
        }
        try fm.copyItem(at: bundledHostScript, to: installedHostScriptPath)
        try fm.copyItem(at: bundledHostWrapper, to: installedHostPath)
        if let bundledBrowserTools {
            try fm.createDirectory(at: installedBrowserToolsDirectory, withIntermediateDirectories: true)
            if fm.fileExists(atPath: installedBrowserToolsExtensionPath.path) {
                try fm.removeItem(at: installedBrowserToolsExtensionPath)
            }
            try fm.copyItem(at: bundledBrowserTools, to: installedBrowserToolsExtensionPath)
        }
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

        if let pairingToken, !pairingToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try writePairingConfig(token: pairingToken)
        } else {
            try writeTrustedOriginPairingConfig()
        }

        return NativeMessagingInstallResult(
            manifestPath: chromeManifestPath.path,
            hostPath: installedHostPath.path,
            allowedOrigin: allowedOrigin
        )
    }
}
