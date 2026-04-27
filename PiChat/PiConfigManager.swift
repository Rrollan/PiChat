import Foundation

struct PiAuthEntry: Identifiable {
    let id: String
    let provider: String
    let type: String
    let keyPreview: String
}

struct MCPServerEntry: Identifiable {
    let id: String
    let name: String
    let description: String
}

struct PiConfigManager {
    static let editableConfigFiles: Set<String> = ["settings.json", "models.json", "auth.json", "mcp.json"]

    let configDir: String

    init(configDir: String = PiConfigManager.defaultConfigDir()) {
        self.configDir = NSString(string: configDir).expandingTildeInPath
    }

    static func defaultConfigDir() -> String {
        if let envDir = ProcessInfo.processInfo.environment["PI_CODING_AGENT_DIR"], !envDir.isEmpty {
            return NSString(string: envDir).expandingTildeInPath
        }
        return NSString(string: "~/.pi/agent").expandingTildeInPath
    }

    func filePath(_ name: String) -> String {
        URL(fileURLWithPath: configDir).appendingPathComponent(name).path
    }

    func validateConfigFileName(_ name: String) throws {
        guard name == URL(fileURLWithPath: name).lastPathComponent,
              Self.editableConfigFiles.contains(name) else {
            throw CocoaError(.fileReadInvalidFileName, userInfo: [NSFilePathErrorKey: name])
        }
    }

    func readJsonFile(named name: String, defaultObject: Any = [:]) throws -> Any {
        try validateConfigFileName(name)
        let path = filePath(name)
        guard FileManager.default.fileExists(atPath: path) else { return defaultObject }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        if data.isEmpty { return defaultObject }
        return try JSONSerialization.jsonObject(with: data)
    }

    func readRawFile(named name: String, defaultContent: String = "{}") -> String {
        guard (try? validateConfigFileName(name)) != nil else { return defaultContent }
        let path = filePath(name)
        guard let data = FileManager.default.contents(atPath: path),
              let text = String(data: data, encoding: .utf8),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return defaultContent
        }
        return text
    }

    func writeRawFile(named name: String, content: String) throws {
        try validateConfigFileName(name)
        _ = try JSONSerialization.jsonObject(with: Data(content.utf8))

        let path = filePath(name)
        let expanded = NSString(string: path).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
        let parent = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        guard let data = content.data(using: .utf8) else { return }

        let tmpURL = parent.appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp")
        try data.write(to: tmpURL, options: .atomic)
        if name == "auth.json" {
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tmpURL.path)
        }
        if FileManager.default.fileExists(atPath: url.path) {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tmpURL)
        } else {
            try FileManager.default.moveItem(at: tmpURL, to: url)
        }
        if name == "auth.json" {
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
    }

    func prettyPrinted(_ object: Any) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    func loadAuthEntries() -> [PiAuthEntry] {
        guard let auth = (try? readJsonFile(named: "auth.json")) as? [String: Any] else { return [] }
        return auth.compactMap { key, value in
            guard let dict = value as? [String: Any] else { return nil }
            let type = (dict["type"] as? String) ?? "unknown"
            let keyValue = (dict["key"] as? String) ?? ""
            return PiAuthEntry(id: key, provider: key, type: type, keyPreview: Self.mask(secret: keyValue))
        }.sorted { $0.provider < $1.provider }
    }

    func upsertApiKey(provider: String, type: String = "api_key", key: String) throws {
        var auth = (try readJsonFile(named: "auth.json", defaultObject: [:])) as? [String: Any] ?? [:]
        auth[provider] = ["type": type, "key": key]
        try writeRawFile(named: "auth.json", content: prettyPrinted(auth))
    }

    func removeAuth(provider: String) throws {
        var auth = (try readJsonFile(named: "auth.json", defaultObject: [:])) as? [String: Any] ?? [:]
        auth.removeValue(forKey: provider)
        try writeRawFile(named: "auth.json", content: prettyPrinted(auth))
    }

    func addCustomModel(providerId: String,
                        baseUrl: String,
                        api: String,
                        apiKey: String,
                        modelId: String,
                        modelName: String?,
                        reasoning: Bool,
                        supportsImages: Bool) throws {
        var root = (try readJsonFile(named: "models.json", defaultObject: ["providers": [:]])) as? [String: Any] ?? [:]
        var providers = root["providers"] as? [String: Any] ?? [:]
        var provider = providers[providerId] as? [String: Any] ?? [:]

        provider["baseUrl"] = baseUrl
        provider["api"] = api
        provider["apiKey"] = apiKey

        var models = provider["models"] as? [[String: Any]] ?? []
        var newModel: [String: Any] = [
            "id": modelId,
            "reasoning": reasoning,
            "input": supportsImages ? ["text", "image"] : ["text"]
        ]
        if let modelName, !modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            newModel["name"] = modelName
        }

        if let index = models.firstIndex(where: { ($0["id"] as? String) == modelId }) {
            models[index].merge(newModel) { _, new in new }
        } else {
            models.append(newModel)
        }

        provider["models"] = models
        providers[providerId] = provider
        root["providers"] = providers
        try writeRawFile(named: "models.json", content: prettyPrinted(root))
    }

    func loadMCPServers() -> [MCPServerEntry] {
        guard let root = (try? readJsonFile(named: "mcp.json")) as? [String: Any] else { return [] }

        let servers: [String: Any]
        if let direct = root["mcpServers"] as? [String: Any] {
            servers = direct
        } else if let nested = (root["mcp"] as? [String: Any])?["servers"] as? [String: Any] {
            servers = nested
        } else {
            return []
        }

        return servers.compactMap { name, value in
            guard let dict = value as? [String: Any] else { return nil }
            let description = (dict["description"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return MCPServerEntry(
                id: name,
                name: name,
                description: (description?.isEmpty == false) ? description! : "MCP server"
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func mask(secret: String) -> String {
        if secret.isEmpty { return "(empty)" }
        if secret.count <= 8 { return String(repeating: "•", count: max(secret.count, 4)) }
        let start = secret.prefix(4)
        let end = secret.suffix(4)
        return "\(start)••••\(end)"
    }
}
