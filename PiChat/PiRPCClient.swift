import Foundation
import Combine

// MARK: - RPC Types

struct RPCCommand: Encodable {
    let id: String?
    let type: String
    var message: String?
    var images: [RPCImage]?
    var streamingBehavior: String?
    var provider: String?
    var modelId: String?
    var level: String?
    var enabled: Bool?
    var mode: String?
    var command: String?
    var customInstructions: String?
    var name: String?
    var sessionPath: String?
    var entryId: String?
    var parentSession: String?

    enum CodingKeys: String, CodingKey {
        case id, type, message, images, provider, level, enabled, mode, command, name
        case streamingBehavior = "streamingBehavior"
        case modelId = "modelId"
        case customInstructions = "customInstructions"
        case sessionPath = "sessionPath"
        case entryId = "entryId"
        case parentSession = "parentSession"
    }
}

struct RPCImage: Encodable {
    let type: String = "image"
    let data: String
    let mimeType: String
}

// MARK: - RPC Response & Events

struct RPCResponse: Decodable {
    let type: String
    let id: String?
    let command: String?
    let success: Bool?
    let error: String?
    let data: RPCResponseData?
}

struct RPCResponseData: Decodable {
    // get_state
    let model: AgentModel?
    let thinkingLevel: String?
    let isStreaming: Bool?
    let isCompacting: Bool?
    let sessionFile: String?
    let sessionId: String?
    let sessionName: String?
    let messageCount: Int?
    let pendingMessageCount: Int?
    let autoCompactionEnabled: Bool?
    let steeringMode: String?
    let followUpMode: String?

    // get_available_models
    let models: [AgentModel]?

    // get_session_stats
    let userMessages: Int?
    let assistantMessages: Int?
    let toolCalls: Int?
    let tokens: TokenStats?
    let cost: Double?
    let contextUsage: ContextUsage?

    // get_commands
    let commands: [AgentCommand]?

    // get_messages
    let messages: [AnyCodable]?

    // compact
    let summary: String?
    let tokensBefore: Int?

    // set_model / cycle_model
    let isScoped: Bool?
}

struct AgentModel: Decodable, Identifiable, Equatable {
    var id: String
    let name: String
    let provider: String
    let api: String?
    let contextWindow: Int?
    let maxTokens: Int?
    let reasoning: Bool?
    let cost: ModelCost?

    static func == (lhs: AgentModel, rhs: AgentModel) -> Bool { lhs.id == rhs.id }
}

struct ModelCost: Decodable {
    let input: Double?
    let output: Double?
    let cacheRead: Double?
    let cacheWrite: Double?
}

struct TokenStats: Decodable {
    let input: Int?
    let output: Int?
    let cacheRead: Int?
    let cacheWrite: Int?
    let total: Int?
}

struct ContextUsage: Decodable {
    let tokens: Int?
    let contextWindow: Int?
    let percent: Double?
}

struct AgentCommand: Decodable, Identifiable {
    var id: String { name }
    let name: String
    let description: String?
    let source: String?
    let path: String?
}

// MARK: - Agent Events

enum AgentEvent {
    case agentStart
    case agentEnd(messages: [AnyCodable])
    case turnStart
    case turnEnd
    case messageStart
    case messageUpdate(delta: MessageDelta)
    case messageEnd
    case toolExecutionStart(toolCallId: String, toolName: String, args: AnyCodable?)
    case toolExecutionUpdate(toolCallId: String, toolName: String, partialText: String)
    case toolExecutionEnd(toolCallId: String, toolName: String, resultText: String, isError: Bool)
    case queueUpdate(steering: [String], followUp: [String])
    case compactionStart(reason: String)
    case compactionEnd(reason: String, summary: String?)
    case autoRetryStart(attempt: Int, maxAttempts: Int, delayMs: Int, errorMessage: String)
    case autoRetryEnd(success: Bool, attempt: Int, finalError: String?)
    case extensionError(extensionPath: String, event: String, error: String)
    case extensionUIRequest(id: String, method: String, title: String?, message: String?, options: [String]?, placeholder: String?, notifyType: String?, prefill: String?)
    case response(id: String?, command: String?, success: Bool, error: String?, data: RPCResponseData?)
}

struct MessageDelta {
    let type: String
    let delta: String?
    let contentIndex: Int?
}

// MARK: - Raw Event Parsing Helper
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) { value = v }
        else if let v = try? container.decode(Int.self) { value = v }
        else if let v = try? container.decode(Double.self) { value = v }
        else if let v = try? container.decode(String.self) { value = v }
        else if let v = try? container.decode([String: AnyCodable].self) { value = v }
        else if let v = try? container.decode([AnyCodable].self) { value = v }
        else { value = NSNull() }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as Bool: try container.encode(v)
        case let v as Int: try container.encode(v)
        case let v as Double: try container.encode(v)
        case let v as String: try container.encode(v)
        case let v as [String: AnyCodable]: try container.encode(v)
        case let v as [AnyCodable]: try container.encode(v)
        default: try container.encodeNil()
        }
    }
}

// MARK: - PiRPCClient

@MainActor
class PiRPCClient: ObservableObject {
    @Published var isRunning = false
    @Published var isStreaming = false

    let eventSubject = PassthroughSubject<AgentEvent, Never>()

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var pendingResponses: [String: CheckedContinuation<RPCResponseData?, Error>] = [:]
    private var lineBuffer = ""
    private var requestCounter = 0
    private var readTask: Task<Void, Never>?

    var piPath: String = "pi"
    var workingDirectory: String = NSHomeDirectory()
    var launchArguments: [String] = ["--no-session"]
    var enableDebugLogging: Bool = false

    // MARK: - Lifecycle

    func start() async throws {
        guard !isRunning else { return }

        let proc = Process()
        let usesEnvLauncher = !piPath.contains("/")
        if usesEnvLauncher {
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            proc.arguments = [piPath, "--mode", "rpc"] + launchArguments
        } else {
            let executablePath = NSString(string: piPath).expandingTildeInPath
            guard FileManager.default.isExecutableFile(atPath: executablePath) else {
                throw RPCError.commandFailed("pi executable not found or not executable: \(piPath)")
            }
            proc.executableURL = URL(fileURLWithPath: executablePath)
            proc.arguments = ["--mode", "rpc"] + launchArguments
        }
        proc.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)

        var env = ProcessInfo.processInfo.environment
        let home = NSHomeDirectory()
        let preferredPathParts = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(home)/.npm-global/bin",
            "\(home)/.local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]
        let existingParts = (env["PATH"] ?? "").split(separator: ":").map(String.init)
        var mergedParts: [String] = []
        for part in preferredPathParts + existingParts {
            guard !part.isEmpty, !mergedParts.contains(part) else { continue }
            mergedParts.append(part)
        }
        env["PATH"] = mergedParts.joined(separator: ":")
        proc.environment = env

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr

        proc.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isRunning = false
                self.isStreaming = false
                for (_, cont) in self.pendingResponses {
                    cont.resume(throwing: RPCError.commandFailed("Process terminated unexpectedly."))
                }
                self.pendingResponses.removeAll()
            }
        }

        try proc.run()

        self.process = proc
        self.stdinPipe = stdin
        self.stdoutPipe = stdout
        self.stderrPipe = stderr
        self.isRunning = true

        // Setup stdout reading via readabilityHandler to avoid AsyncBytes buffering bugs
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard data.count > 0 else { return }
            guard let str = String(data: data, encoding: .utf8) else { return }
            
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.lineBuffer += str
                while let newlineRange = self.lineBuffer.range(of: "\n") {
                    var line = String(self.lineBuffer[self.lineBuffer.startIndex..<newlineRange.lowerBound])
                    self.lineBuffer.removeSubrange(self.lineBuffer.startIndex...newlineRange.lowerBound)
                    if line.hasSuffix("\r") { line.removeLast() }
                    if !line.isEmpty {
                        await self.handleLine(line)
                    }
                }
            }
        }

        // Setup stderr reading similarly
        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.count > 0, let str = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    self?.debugLog("[PI STDERR]: \(str.trimmingCharacters(in: .newlines))")
                }
            }
        }
    }

    func stop() {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        readTask?.cancel()
        process?.terminate()
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
        isRunning = false
        isStreaming = false
        lineBuffer = ""
        pendingResponses.removeAll()
    }

    // MARK: - Reading

    @MainActor
    private func handleLine(_ line: String) async {
        debugLog("[RPC RX] \(line)")
        guard let data = line.data(using: .utf8) else { return }

        // Try to parse as raw dict first for flexible handling
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        let eventType = json["type"] as? String ?? ""

        switch eventType {
        case "response":
            let id = json["id"] as? String
            let command = json["command"] as? String
            let success = json["success"] as? Bool ?? false
            let error = json["error"] as? String
            var responseData: RPCResponseData? = nil
            if let dataDict = json["data"],
               let dataJson = try? JSONSerialization.data(withJSONObject: dataDict) {
                responseData = try? JSONDecoder().decode(RPCResponseData.self, from: dataJson)
            }
            if let reqId = id, let cont = pendingResponses[reqId] {
                pendingResponses.removeValue(forKey: reqId)
                if success {
                    cont.resume(returning: responseData)
                } else {
                    cont.resume(throwing: RPCError.commandFailed(error ?? "Unknown error"))
                }
            }
            eventSubject.send(.response(id: id, command: command, success: success, error: error, data: responseData))

        case "agent_start":
            isStreaming = true
            eventSubject.send(.agentStart)

        case "agent_end":
            isStreaming = false
            eventSubject.send(.agentEnd(messages: []))

        case "turn_start":
            eventSubject.send(.turnStart)

        case "turn_end":
            eventSubject.send(.turnEnd)

        case "message_start":
            eventSubject.send(.messageStart)

        case "message_end":
            eventSubject.send(.messageEnd)

        case "message_update":
            if let evt = json["assistantMessageEvent"] as? [String: Any] {
                let t = evt["type"] as? String ?? ""
                let delta = evt["delta"] as? String
                let idx = evt["contentIndex"] as? Int
                let md = MessageDelta(type: t, delta: delta, contentIndex: idx)
                eventSubject.send(.messageUpdate(delta: md))
            }

        case "tool_execution_start":
            let tcId = json["toolCallId"] as? String ?? ""
            let tn = json["toolName"] as? String ?? ""
            eventSubject.send(.toolExecutionStart(toolCallId: tcId, toolName: tn, args: nil))

        case "tool_execution_update":
            let tcId = json["toolCallId"] as? String ?? ""
            let tn = json["toolName"] as? String ?? ""
            var partial = ""
            if let pr = json["partialResult"] as? [String: Any],
               let content = pr["content"] as? [[String: Any]],
               let first = content.first,
               let text = first["text"] as? String {
                partial = text
            }
            eventSubject.send(.toolExecutionUpdate(toolCallId: tcId, toolName: tn, partialText: partial))

        case "tool_execution_end":
            let tcId = json["toolCallId"] as? String ?? ""
            let tn = json["toolName"] as? String ?? ""
            let isErr = json["isError"] as? Bool ?? false
            var resultText = ""
            if let res = json["result"] as? [String: Any],
               let content = res["content"] as? [[String: Any]],
               let first = content.first,
               let text = first["text"] as? String {
                resultText = text
            }
            eventSubject.send(.toolExecutionEnd(toolCallId: tcId, toolName: tn, resultText: resultText, isError: isErr))

        case "queue_update":
            let steering = json["steering"] as? [String] ?? []
            let followUp = json["followUp"] as? [String] ?? []
            eventSubject.send(.queueUpdate(steering: steering, followUp: followUp))

        case "compaction_start":
            let reason = json["reason"] as? String ?? ""
            eventSubject.send(.compactionStart(reason: reason))

        case "compaction_end":
            let reason = json["reason"] as? String ?? ""
            var summary: String? = nil
            if let res = json["result"] as? [String: Any] {
                summary = res["summary"] as? String
            }
            eventSubject.send(.compactionEnd(reason: reason, summary: summary))

        case "auto_retry_start":
            eventSubject.send(.autoRetryStart(
                attempt: json["attempt"] as? Int ?? 0,
                maxAttempts: json["maxAttempts"] as? Int ?? 0,
                delayMs: json["delayMs"] as? Int ?? 0,
                errorMessage: json["errorMessage"] as? String ?? ""
            ))

        case "auto_retry_end":
            eventSubject.send(.autoRetryEnd(
                success: json["success"] as? Bool ?? false,
                attempt: json["attempt"] as? Int ?? 0,
                finalError: json["finalError"] as? String
            ))

        case "extension_error":
            eventSubject.send(.extensionError(
                extensionPath: json["extensionPath"] as? String ?? "",
                event: json["event"] as? String ?? "",
                error: json["error"] as? String ?? ""
            ))

        case "extension_ui_request":
            let id = json["id"] as? String ?? ""
            let method = json["method"] as? String ?? ""
            eventSubject.send(.extensionUIRequest(
                id: id, method: method,
                title: json["title"] as? String,
                message: json["message"] as? String,
                options: json["options"] as? [String],
                placeholder: json["placeholder"] as? String,
                notifyType: json["notifyType"] as? String,
                prefill: json["prefill"] as? String
            ))

        default:
            break
        }
    }

    // MARK: - Sending Commands

    @discardableResult
    func sendCommand(_ cmd: RPCCommand) async throws -> RPCResponseData? {
        guard isRunning, let pipe = stdinPipe else {
            throw RPCError.notConnected
        }
        let data = try JSONEncoder().encode(cmd)
        guard var line = String(data: data, encoding: .utf8) else {
            throw RPCError.encodingFailed
        }
        line += "\n"
        guard let lineData = line.data(using: .utf8) else {
            throw RPCError.encodingFailed
        }

        debugLog("[RPC TX] \(line.trimmingCharacters(in: .newlines))")

        if let reqId = cmd.id {
            return try await withCheckedThrowingContinuation { cont in
                self.pendingResponses[reqId] = cont
                pipe.fileHandleForWriting.write(lineData)
            }
        } else {
            pipe.fileHandleForWriting.write(lineData)
            return nil
        }
    }

    private func nextId() -> String {
        requestCounter += 1
        return "req-\(requestCounter)"
    }

    // MARK: - High-level API

    func prompt(_ message: String, images: [RPCImage] = []) async throws {
        let cmd = RPCCommand(
            id: nextId(), type: "prompt",
            message: message,
            images: images.isEmpty ? nil : images
        )
        try await sendCommand(cmd)
    }

    func abort() async throws {
        try await sendCommand(RPCCommand(id: nextId(), type: "abort"))
    }

    func getState() async throws -> RPCResponseData? {
        try await sendCommand(RPCCommand(id: nextId(), type: "get_state"))
    }

    func getAvailableModels() async throws -> [AgentModel] {
        let data = try await sendCommand(RPCCommand(id: nextId(), type: "get_available_models"))
        return data?.models ?? []
    }

    func setModel(provider: String, modelId: String) async throws {
        let cmd = RPCCommand(id: nextId(), type: "set_model")
        let cmd2 = RPCCommand(id: cmd.id, type: "set_model", message: nil, images: nil,
                               streamingBehavior: nil, provider: provider, modelId: modelId)
        try await sendCommand(cmd2)
    }

    func setThinkingLevel(_ level: String) async throws {
        let cmd = RPCCommand(id: nextId(), type: "set_thinking_level")
        let cmd2 = RPCCommand(id: cmd.id, type: "set_thinking_level", message: nil, images: nil,
                               streamingBehavior: nil, provider: nil, modelId: nil, level: level)
        try await sendCommand(cmd2)
    }

    func setSteeringMode(_ mode: String) async throws {
        let cmd = RPCCommand(id: nextId(), type: "set_steering_mode", mode: mode)
        try await sendCommand(cmd)
    }

    func setFollowUpMode(_ mode: String) async throws {
        let cmd = RPCCommand(id: nextId(), type: "set_follow_up_mode", mode: mode)
        try await sendCommand(cmd)
    }

    func setAutoCompaction(enabled: Bool) async throws {
        let cmd = RPCCommand(id: nextId(), type: "set_auto_compaction", enabled: enabled)
        try await sendCommand(cmd)
    }

    func setAutoRetry(enabled: Bool) async throws {
        let cmd = RPCCommand(id: nextId(), type: "set_auto_retry", enabled: enabled)
        try await sendCommand(cmd)
    }

    func getCommands() async throws -> [AgentCommand] {
        let data = try await sendCommand(RPCCommand(id: nextId(), type: "get_commands"))
        return data?.commands ?? []
    }

    func getSessionStats() async throws -> RPCResponseData? {
        try await sendCommand(RPCCommand(id: nextId(), type: "get_session_stats"))
    }

    func compact(customInstructions: String? = nil) async throws {
        let cmd = RPCCommand(id: nextId(), type: "compact", message: nil, images: nil,
                              streamingBehavior: nil, provider: nil, modelId: nil, level: nil,
                              enabled: nil, customInstructions: customInstructions)
        try await sendCommand(cmd)
    }

    func newSession() async throws {
        try await sendCommand(RPCCommand(id: nextId(), type: "new_session"))
    }

    func sendExtensionUIResponse(id: String, value: String? = nil, confirmed: Bool? = nil, cancelled: Bool? = nil) {
        guard isRunning, let pipe = stdinPipe else { return }
        var dict: [String: Any] = ["type": "extension_ui_response", "id": id]
        if let v = value { dict["value"] = v }
        if let c = confirmed { dict["confirmed"] = c }
        if let c = cancelled { dict["cancelled"] = c }
        if let data = try? JSONSerialization.data(withJSONObject: dict),
           var line = String(data: data, encoding: .utf8) {
            line += "\n"
            if let lineData = line.data(using: .utf8) {
                pipe.fileHandleForWriting.write(lineData)
            }
        }
    }

    private func debugLog(_ message: String) {
        guard enableDebugLogging else { return }
        print(message)
    }

    // MARK: - Errors
    enum RPCError: Error, LocalizedError {
        case notConnected
        case encodingFailed
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .notConnected: return "pi is not running"
            case .encodingFailed: return "Failed to encode command"
            case .commandFailed(let msg): return msg
            }
        }
    }
}
