import Foundation
import Combine
import SwiftUI
import AppKit

// MARK: - Chat Message Model

enum ChatRole {
    case user, assistant, system, tool
}

struct ToolCall: Identifiable {
    let id: String
    let name: String
    var args: String
    var output: String
    var isError: Bool
    var isRunning: Bool
    var isExpanded: Bool = false
}

struct ChatMessage: Identifiable {
    let id = UUID()
    var role: ChatRole
    var text: String
    var isStreaming: Bool = false
    var thinkingText: String = ""
    var showThinking: Bool = false
    var toolCalls: [ToolCall] = []
    var timestamp: Date = Date()
    var attachments: [FileAttachment] = []
}

struct FileAttachment: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let mimeType: String
    var base64Data: String?
    var isImage: Bool { mimeType.hasPrefix("image/") }
}

// MARK: - App State

@MainActor
class AppState: ObservableObject {

    // MARK: Connection
    @Published var isConnected = false
    @Published var isStarting = false
    @Published var connectionError: String?

    // MARK: Chat
    @Published var messages: [ChatMessage] = []
    @Published var isStreaming = false
    @Published var isWaitingForResponse = false

    // MARK: Model & Session
    @Published var currentModel: AgentModel?
    @Published var availableModels: [AgentModel] = []
    @Published var thinkingLevel: String = "off"
    @Published var steeringMode: String = "one-at-a-time"
    @Published var followUpMode: String = "one-at-a-time"
    @Published var autoCompactionEnabled: Bool = true
    @Published var autoRetryEnabled: Bool = true
    @Published var sessionFile: String?
    @Published var sessionId: String?
    @Published var sessionName: String?

    // MARK: Stats
    @Published var tokenInput: Int = 0
    @Published var tokenOutput: Int = 0
    @Published var tokenTotal: Int = 0
    @Published var sessionCost: Double = 0
    @Published var contextPercent: Double = 0
    @Published var contextTokens: Int = 0
    @Published var contextWindow: Int = 0

    // MARK: Commands / Skills
    @Published var commands: [AgentCommand] = []
    var skills: [AgentCommand] { commands.filter { $0.source == "skill" } }
    var extensionCommands: [AgentCommand] { commands.filter { $0.source == "extension" } }
    var promptTemplates: [AgentCommand] { commands.filter { $0.source == "prompt" } }

    // MARK: Queue
    @Published var steeringQueue: [String] = []
    @Published var followUpQueue: [String] = []

    // MARK: Tool Activity
    @Published var activeTools: [ToolCall] = []

    // MARK: Notifications
    @Published var notification: AppNotification?
    @Published var isOAuthLoginRunning: Bool = false
    @Published var oauthLoginStatusText: String?
    @Published var oauthPromptMessage: String?
    @Published var oauthPromptPlaceholder: String?
    @Published var oauthPromptInput: String = ""

    // MARK: Keyboard / Action Feedback
    @Published var keyFeedbackText: String?
    @Published var busyActionText: String?

    // MARK: Extension UI
    @Published var pendingUIRequest: ExtensionUIRequest?

    // MARK: Input
    @Published var inputText: String = ""
    @Published var attachedFiles: [FileAttachment] = []

    // MARK: Pi Runtime & Config
    @Published var piPath: String
    @Published var startupDirectory: String
    @Published var piConfigDirectory: String
    @Published var settingsJSONText: String = "{}"
    @Published var modelsJSONText: String = "{}"
    @Published var authJSONText: String = "{}"
    @Published var authEntries: [PiAuthEntry] = []
    @Published var mcpServers: [MCPServerEntry] = []

    // MARK: settings.json (full)
    @Published var sDefaultProvider = ""
    @Published var sDefaultModel = ""
    @Published var sDefaultThinkingLevel = "off"
    @Published var sHideThinkingBlock = false
    @Published var sThinkingMinimal = "1024"
    @Published var sThinkingLow = "4096"
    @Published var sThinkingMedium = "10240"
    @Published var sThinkingHigh = "32768"
    @Published var sTheme = "dark"
    @Published var sQuietStartup = false
    @Published var sCollapseChangelog = false
    @Published var sEnableInstallTelemetry = true
    @Published var sDoubleEscapeAction = "tree"
    @Published var sTreeFilterMode = "default"
    @Published var sEditorPaddingX = "0"
    @Published var sAutocompleteMaxVisible = "5"
    @Published var sShowHardwareCursor = false
    @Published var sCompactionEnabled = true
    @Published var sCompactionReserveTokens = "16384"
    @Published var sCompactionKeepRecentTokens = "20000"
    @Published var sBranchSummaryReserveTokens = "16384"
    @Published var sBranchSummarySkipPrompt = false
    @Published var sRetryEnabled = true
    @Published var sRetryMaxRetries = "3"
    @Published var sRetryBaseDelayMs = "2000"
    @Published var sRetryMaxDelayMs = "60000"
    @Published var sSteeringMode = "one-at-a-time"
    @Published var sFollowUpMode = "one-at-a-time"
    @Published var sTransport = "sse"
    @Published var sTerminalShowImages = true
    @Published var sTerminalImageWidthCells = "60"
    @Published var sTerminalClearOnShrink = false
    @Published var sImagesAutoResize = true
    @Published var sImagesBlockImages = false
    @Published var sShellPath = ""
    @Published var sShellCommandPrefix = ""
    @Published var sNpmCommand = ""
    @Published var sSessionDir = ""
    @Published var sEnabledModels = ""
    @Published var sMarkdownCodeBlockIndent = "  "
    @Published var sPackages = ""
    @Published var sExtensions = ""
    @Published var sSkills = ""
    @Published var sPrompts = ""
    @Published var sThemes = ""
    @Published var sEnableSkillCommands = true

    // MARK: CLI launch options (rpc)
    @Published var cliNoSession = true
    @Published var cliProvider = ""
    @Published var cliModel = ""
    @Published var cliApiKey = ""
    @Published var cliThinking = ""
    @Published var cliModels = ""
    @Published var cliSessionDir = ""
    @Published var cliSession = ""
    @Published var cliFork = ""
    @Published var cliTools = ""
    @Published var cliNoTools = false
    @Published var cliNoExtensions = false
    @Published var cliNoSkills = false
    @Published var cliNoPromptTemplates = false
    @Published var cliNoThemes = false
    @Published var cliNoContextFiles = false
    @Published var cliVerbose = false
    @Published var cliSystemPrompt = ""
    @Published var cliAppendSystemPrompt = ""
    @Published var cliExtraArgs = ""

    // MARK: Compaction
    @Published var isCompacting = false
    @Published var lastCompactionSummary: String?

    // MARK: Retry
    @Published var isRetrying = false
    @Published var retryMessage: String?

    // MARK: App Update
    @Published var isCheckingForUpdates = false

    // MARK: Install Location Hint
    @Published var shouldSuggestMoveToApplications = false

    let rpc = PiRPCClient()
    private var configManager: PiConfigManager {
        PiConfigManager(configDir: piConfigDirectory)
    }
    private var cancellables = Set<AnyCancellable>()
    private var currentAssistantMessageIndex: Int?
    private var activeToolCallMap: [String: Int] = [:] // toolCallId -> index in activeTools
    private var responseWatchdogTask: Task<Void, Never>?
    private var keyFeedbackTask: Task<Void, Never>?
    private var busyActionDepth = 0
    private var oauthHelperInputHandle: FileHandle?
    private var oauthHelperProcess: Process?

    init() {
        let defaults = UserDefaults.standard
        self.piPath = defaults.string(forKey: "pi.runtime.path") ?? "pi"
        self.startupDirectory = defaults.string(forKey: "pi.runtime.startupDirectory") ?? NSHomeDirectory()
        self.piConfigDirectory = defaults.string(forKey: "pi.runtime.configDirectory") ?? PiConfigManager.defaultConfigDir()
        self.cliNoSession = defaults.object(forKey: "pi.cli.noSession") as? Bool ?? true
        self.cliProvider = defaults.string(forKey: "pi.cli.provider") ?? ""
        self.cliModel = defaults.string(forKey: "pi.cli.model") ?? ""
        self.cliApiKey = defaults.string(forKey: "pi.cli.apiKey") ?? ""
        self.cliThinking = defaults.string(forKey: "pi.cli.thinking") ?? ""
        self.cliModels = defaults.string(forKey: "pi.cli.models") ?? ""
        self.cliSessionDir = defaults.string(forKey: "pi.cli.sessionDir") ?? ""
        self.cliSession = defaults.string(forKey: "pi.cli.session") ?? ""
        self.cliFork = defaults.string(forKey: "pi.cli.fork") ?? ""
        self.cliTools = defaults.string(forKey: "pi.cli.tools") ?? ""
        self.cliNoTools = defaults.bool(forKey: "pi.cli.noTools")
        self.cliNoExtensions = defaults.bool(forKey: "pi.cli.noExtensions")
        self.cliNoSkills = defaults.bool(forKey: "pi.cli.noSkills")
        self.cliNoPromptTemplates = defaults.bool(forKey: "pi.cli.noPromptTemplates")
        self.cliNoThemes = defaults.bool(forKey: "pi.cli.noThemes")
        self.cliNoContextFiles = defaults.bool(forKey: "pi.cli.noContextFiles")
        self.cliVerbose = defaults.bool(forKey: "pi.cli.verbose")
        self.cliSystemPrompt = defaults.string(forKey: "pi.cli.systemPrompt") ?? ""
        self.cliAppendSystemPrompt = defaults.string(forKey: "pi.cli.appendSystemPrompt") ?? ""
        self.cliExtraArgs = defaults.string(forKey: "pi.cli.extraArgs") ?? ""
        setupEventHandling()
        loadConfigFiles()
    }

    // MARK: - Setup

    private func setupEventHandling() {
        rpc.eventSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleEvent(event)
            }
            .store(in: &cancellables)
    }

    // MARK: - Connect / Disconnect

    func connect(piPath: String? = nil, workingDirectory: String? = nil) async {
        isStarting = true
        connectionError = nil
        let resolvedPiPath = (piPath ?? self.piPath).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "pi" : (piPath ?? self.piPath)
        let candidateDirectory = workingDirectory ?? self.startupDirectory
        let resolvedWorkingDirectory = candidateDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? NSHomeDirectory() : candidateDirectory
        self.piPath = resolvedPiPath
        self.startupDirectory = resolvedWorkingDirectory
        persistRuntimeSettings()

        rpc.piPath = resolvedPiPath
        rpc.workingDirectory = resolvedWorkingDirectory
        rpc.launchArguments = buildRpcLaunchArguments()
        rpc.enableDebugLogging = cliVerbose

        do {
            try await rpc.start()
            isConnected = true
            // Give pi 800ms to initialize
            try? await Task.sleep(nanoseconds: 800_000_000)
            await loadInitialState()
        } catch {
            connectionError = error.localizedDescription
        }
        isStarting = false
    }

    func disconnect() {
        responseWatchdogTask?.cancel()
        rpc.stop()
        isConnected = false
        messages.removeAll()
        activeTools.removeAll()
    }

    func changeProject(newDirectory: String) async {
        disconnect()
        startupDirectory = newDirectory
        persistRuntimeSettings()
        await connect(piPath: rpc.piPath, workingDirectory: newDirectory)
    }

    private func loadInitialState() async {
        async let state = try? rpc.getState()
        async let models = (try? rpc.getAvailableModels()) ?? []
        async let cmds = (try? rpc.getCommands()) ?? []

        let (s, m, c) = await (state, models, cmds)

        if let s {
            applyState(s)
        }
        availableModels = m
        commands = c
    }

    private func applyState(_ data: RPCResponseData) {
        currentModel = data.model
        thinkingLevel = data.thinkingLevel ?? "off"
        sessionFile = data.sessionFile
        sessionId = data.sessionId
        sessionName = data.sessionName
        isStreaming = data.isStreaming ?? false
        isCompacting = data.isCompacting ?? false
        steeringMode = data.steeringMode ?? steeringMode
        followUpMode = data.followUpMode ?? followUpMode
        autoCompactionEnabled = data.autoCompactionEnabled ?? autoCompactionEnabled
    }

    // MARK: - Event Handling

    private func handleEvent(_ event: AgentEvent) {
        switch event {

        case .agentStart:
            responseWatchdogTask?.cancel()
            isWaitingForResponse = false
            isStreaming = true
            let msg = ChatMessage(role: .assistant, text: "", isStreaming: true)
            messages.append(msg)
            currentAssistantMessageIndex = messages.count - 1

        case .agentEnd:
            isWaitingForResponse = false
            isStreaming = false
            if let idx = currentAssistantMessageIndex {
                messages[idx].isStreaming = false
            }
            currentAssistantMessageIndex = nil
            // Refresh stats
            Task { await refreshStats() }

        case .messageUpdate(let delta):
            guard let idx = currentAssistantMessageIndex else { return }
            switch delta.type {
            case "text_delta":
                messages[idx].text += delta.delta ?? ""
            case "thinking_delta":
                messages[idx].thinkingText += delta.delta ?? ""
                messages[idx].showThinking = true
            default: break
            }

        case .toolExecutionStart(let tcId, let tn, _):
            let tool = ToolCall(id: tcId, name: tn, args: "", output: "", isError: false, isRunning: true)
            activeTools.append(tool)
            activeToolCallMap[tcId] = activeTools.count - 1

            // Also add to current message's tool calls
            if let idx = currentAssistantMessageIndex {
                messages[idx].toolCalls.append(tool)
            }

        case .toolExecutionUpdate(let tcId, _, let partial):
            if let i = activeToolCallMap[tcId] {
                activeTools[i].output = partial
            }
            // Update in message too
            if let msgIdx = currentAssistantMessageIndex {
                if let tIdx = messages[msgIdx].toolCalls.firstIndex(where: { $0.id == tcId }) {
                    messages[msgIdx].toolCalls[tIdx].output = partial
                }
            }

        case .toolExecutionEnd(let tcId, _, let result, let isErr):
            if let i = activeToolCallMap[tcId] {
                activeTools[i].output = result
                activeTools[i].isError = isErr
                activeTools[i].isRunning = false
            }
            if let msgIdx = currentAssistantMessageIndex {
                if let tIdx = messages[msgIdx].toolCalls.firstIndex(where: { $0.id == tcId }) {
                    messages[msgIdx].toolCalls[tIdx].output = result
                    messages[msgIdx].toolCalls[tIdx].isError = isErr
                    messages[msgIdx].toolCalls[tIdx].isRunning = false
                }
            }
            activeToolCallMap.removeValue(forKey: tcId)
            // Remove from active after short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.activeTools.removeAll { $0.id == tcId && !$0.isRunning }
            }

        case .queueUpdate(let s, let f):
            steeringQueue = s
            followUpQueue = f

        case .compactionStart:
            isCompacting = true
            addSystemMessage("🗜 Compacting context…")

        case .compactionEnd(_, let summary):
            isCompacting = false
            if let s = summary {
                lastCompactionSummary = s
                addSystemMessage("✅ Compaction complete")
            }

        case .autoRetryStart(let attempt, let max, let delay, _):
            isRetrying = true
            retryMessage = "Retrying (\(attempt)/\(max)) in \(delay/1000)s…"

        case .autoRetryEnd(let success, _, let finalError):
            isRetrying = false
            retryMessage = nil
            if !success, let err = finalError {
                logAgentError(err, context: "auto_retry_end")
                addSystemMessage("❌ Failed after retries: \(err)")
            }

        case .extensionUIRequest(let id, let method, let title, let message, let options, let placeholder, let notifyType, let prefill):
            if method == "notify" {
                show(notification: AppNotification(
                    message: message ?? title ?? "",
                    type: notifyType == "error" ? .error : notifyType == "warning" ? .warning : .info
                ))
            } else if ["confirm", "select", "input", "editor"].contains(method) {
                pendingUIRequest = ExtensionUIRequest(
                    id: id, method: method, title: title, message: message,
                    options: options, placeholder: placeholder, prefill: prefill
                )
            } else {
                // For non-interactive UI updates like setStatus, setWidget, setTitle, just ack immediately.
                rpc.sendExtensionUIResponse(id: id)
            }

        case .extensionError(_, _, let error):
            logAgentError(error, context: "extension_error")
            addSystemMessage("⚠️ Extension error: \(error)")

        case .processStderr(let message):
            let lowered = message.lowercased()
            let looksLikeError = lowered.contains("error") || lowered.contains("failed") || lowered.contains("limit") || lowered.contains("429")
            if looksLikeError {
                logAgentError(message, context: "pi_stderr")
            }

        case .response(_, let command, let success, let error, let data):
            if command == "prompt", !success {
                responseWatchdogTask?.cancel()
                isWaitingForResponse = false
            }
            if let e = error {
                logAgentError(e, context: "response:\(command ?? "unknown")")
                show(notification: AppNotification(message: e, type: .error))
                if command == "prompt" {
                    addSystemMessage("❌ Agent response error: \(e)")
                }
            }
            if command == "set_model" || command == "cycle_model" {
                if let m = data?.model { currentModel = m }
            }
            if command == "set_thinking_level" {
                // refresh state
                Task { if let s = try? await rpc.getState() { applyState(s) } }
            }
            if command == "set_steering_mode" || command == "set_follow_up_mode" || command == "set_auto_compaction" || command == "set_auto_retry" {
                Task { if let s = try? await rpc.getState() { applyState(s) } }
            }

        default: break
        }
    }

    private func addSystemMessage(_ text: String) {
        messages.append(ChatMessage(role: .system, text: text))
    }

    private func logAgentError(_ message: String, context: String) {
        AgentErrorLogger.log(message, context: context)
    }

    private func startResponseWatchdog() {
        responseWatchdogTask?.cancel()
        responseWatchdogTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            guard let self else { return }
            guard self.isWaitingForResponse, !self.isStreaming else { return }

            let msg = "Agent did not start responding in time. You may have hit a rate limit or quota. Details: ~/Library/Logs/PiChat/agent-errors.log"
            self.logAgentError(msg, context: "response_timeout")
            self.addSystemMessage("⚠️ \(msg)")
            self.show(notification: AppNotification(message: "Agent is silent for too long — check limits and error logs", type: .warning))
            self.isWaitingForResponse = false
        }
    }

    // MARK: - Actions

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !attachedFiles.isEmpty else { return }

        let userMsg = ChatMessage(role: .user, text: text, attachments: attachedFiles)
        messages.append(userMsg)

        let images: [RPCImage] = attachedFiles.compactMap { att in
            guard att.isImage, let b64 = att.base64Data else { return nil }
            return RPCImage(data: b64, mimeType: att.mimeType)
        }

        inputText = ""
        attachedFiles = []
        isWaitingForResponse = true
        startResponseWatchdog()

        do {
            try await rpc.prompt(text, images: images)
        } catch {
            responseWatchdogTask?.cancel()
            isWaitingForResponse = false
            logAgentError(error.localizedDescription, context: "prompt_send")
            addSystemMessage("❌ \(error.localizedDescription)")
        }
    }

    func startProviderLogin(_ provider: String?) async {
        let providerId = (provider ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !providerId.isEmpty else {
            oauthLoginStatusText = "Provider is required"
            return
        }
        guard !isOAuthLoginRunning else { return }

        isOAuthLoginRunning = true
        oauthLoginStatusText = "Starting authentication for \(providerId)…"
        oauthPromptMessage = nil
        oauthPromptPlaceholder = nil
        oauthPromptInput = ""

        defer {
            isOAuthLoginRunning = false
            oauthHelperInputHandle = nil
            oauthHelperProcess = nil
        }

        do {
            try await runOAuthLogin(providerId: providerId)
            loadConfigFiles()
            oauthPromptMessage = nil
            oauthPromptPlaceholder = nil
            oauthPromptInput = ""
            oauthLoginStatusText = "Authentication completed: \(providerId)"
        } catch {
            let fallback = "Authentication failed for \(providerId): \(error.localizedDescription)"
            if let status = oauthLoginStatusText, !status.isEmpty, status != "Starting authentication for \(providerId)…" {
                oauthLoginStatusText = status
            } else {
                oauthLoginStatusText = fallback
            }
        }
    }

    func submitOAuthPromptInput() {
        guard let handle = oauthHelperInputHandle else { return }
        let text = oauthPromptInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let line = text + "\n"
        if let data = line.data(using: .utf8) {
            handle.write(data)
            oauthPromptInput = ""
            oauthLoginStatusText = "Submitted verification input…"
            oauthPromptMessage = nil
            oauthPromptPlaceholder = nil
        }
    }

    func cancelOAuthLogin() {
        oauthHelperProcess?.terminate()
        oauthHelperProcess = nil
        oauthHelperInputHandle = nil
        isOAuthLoginRunning = false
        oauthLoginStatusText = "Authentication cancelled"
    }

    private func runOAuthLogin(providerId: String) async throws {
        let script = """
import { AuthStorage } from 'file:///opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/dist/core/auth-storage.js';
import readline from 'node:readline';

const providerId = process.argv[1];
const authPath = process.argv[2];

const send = (obj) => process.stdout.write(JSON.stringify(obj) + '\\n');
const rl = readline.createInterface({ input: process.stdin, output: process.stdout, terminal: false });
const readInputLine = () => new Promise((resolve) => rl.once('line', (line) => resolve((line ?? '').trim())));

try {
  const storage = AuthStorage.create(authPath);
  await storage.login(providerId, {
    onAuth: (info) => send({ type: 'auth', url: info?.url ?? '', instructions: info?.instructions ?? '' }),
    onProgress: (message) => send({ type: 'progress', message: message ?? '' }),
    onPrompt: async (prompt) => {
      send({ type: 'prompt', message: prompt?.message ?? 'Enter the requested value', placeholder: prompt?.placeholder ?? '' });
      return await readInputLine();
    },
    onManualCodeInput: async () => {
      send({ type: 'manual', message: 'Paste the authorization code or full redirect URL.' });
      return await readInputLine();
    }
  });
  send({ type: 'done' });
  rl.close();
} catch (error) {
  send({ type: 'error', message: error?.message ?? String(error) });
  rl.close();
  process.exit(1);
}
"""

        let authPath = URL(fileURLWithPath: piConfigDirectory).appendingPathComponent("auth.json").path

        let nodeExecutable = resolveNodeExecutable()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: nodeExecutable)
        process.arguments = ["--input-type=module", "-e", script, providerId, authPath]

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        oauthHelperInputHandle = stdin.fileHandleForWriting
        oauthHelperProcess = process

        var stdoutBuffer = ""
        var stderrBuffer = ""

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }

            Task { @MainActor [weak self] in
                guard let self else { return }
                stdoutBuffer += chunk

                while let newline = stdoutBuffer.firstIndex(of: "\n") {
                    let line = String(stdoutBuffer[..<newline])
                    stdoutBuffer = String(stdoutBuffer[stdoutBuffer.index(after: newline)...])
                    self.handleOAuthHelperEventLine(line)
                }
            }
        }

        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }

            Task { @MainActor [weak self] in
                guard let self else { return }
                stderrBuffer += chunk
                let cleaned = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty {
                    self.oauthLoginStatusText = cleaned
                }
            }
        }

        try process.run()

        let status = await withCheckedContinuation { (continuation: CheckedContinuation<Int32, Never>) in
            process.terminationHandler = { proc in
                continuation.resume(returning: proc.terminationStatus)
            }
        }

        stdout.fileHandleForReading.readabilityHandler = nil
        stderr.fileHandleForReading.readabilityHandler = nil
        oauthHelperInputHandle = nil
        oauthHelperProcess = nil

        if status != 0 {
            let errText = stderrBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(domain: "PiChatOAuth", code: Int(status), userInfo: [
                NSLocalizedDescriptionKey: errText.isEmpty ? "OAuth helper failed" : errText
            ])
        }
    }

    private func resolveNodeExecutable() -> String {
        let candidates = [
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node",
            "/usr/bin/node"
        ]

        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }

        return "node"
    }

    private func handleOAuthHelperEventLine(_ line: String) {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = obj["type"] as? String else { return }

        switch type {
        case "auth":
            if let urlString = obj["url"] as? String, let url = URL(string: urlString), !urlString.isEmpty {
                NSWorkspace.shared.open(url)
                oauthLoginStatusText = "Browser opened. Complete authentication, then paste verification data below if requested."
            }

        case "progress":
            if let message = obj["message"] as? String, !message.isEmpty {
                oauthLoginStatusText = message
            }

        case "prompt", "manual":
            if let message = obj["message"] as? String, !message.isEmpty {
                oauthPromptMessage = message
                oauthPromptPlaceholder = obj["placeholder"] as? String
                oauthLoginStatusText = message
            }

        case "done":
            oauthPromptMessage = nil
            oauthPromptPlaceholder = nil

        case "error":
            if let message = obj["message"] as? String, !message.isEmpty {
                oauthLoginStatusText = message
                oauthPromptMessage = message
            }

        default:
            break
        }
    }

    func abortCurrentOperation() async {
        responseWatchdogTask?.cancel()
        isWaitingForResponse = false
        try? await rpc.abort()
    }

    func refreshStats() async {
        guard let data = try? await rpc.getSessionStats() else { return }
        tokenInput = data.tokens?.input ?? 0
        tokenOutput = data.tokens?.output ?? 0
        tokenTotal = data.tokens?.total ?? 0
        sessionCost = data.cost ?? 0
        contextPercent = data.contextUsage?.percent ?? 0
        contextTokens = data.contextUsage?.tokens ?? 0
        contextWindow = data.contextUsage?.contextWindow ?? 0
    }

    func refreshCommands() async {
        commands = (try? await rpc.getCommands()) ?? []
    }

    func startNewSession() async {
        beginBusyAction("Creating new session…")
        defer { endBusyAction() }

        do {
            try await rpc.newSession()
            messages.removeAll()
            activeTools.removeAll()
            await loadInitialState()
        } catch {
            show(notification: AppNotification(message: "Failed to create new session: \(error.localizedDescription)", type: .error))
        }
    }

    func compact() async {
        beginBusyAction("Requesting compact…")
        defer { endBusyAction() }

        do {
            try await rpc.compact()
        } catch {
            show(notification: AppNotification(message: "Failed to run compact: \(error.localizedDescription)", type: .error))
        }
    }

    func setModel(_ model: AgentModel) async {
        try? await rpc.setModel(provider: model.provider, modelId: model.id)
        currentModel = model
    }

    func setThinkingLevel(_ level: String) async {
        try? await rpc.setThinkingLevel(level)
        thinkingLevel = level
    }

    func setSteeringMode(_ mode: String) async {
        do {
            try await rpc.setSteeringMode(mode)
            steeringMode = mode
        } catch {
            show(notification: AppNotification(message: "Failed to apply steering mode: \(error.localizedDescription)", type: .error))
        }
    }

    func setFollowUpMode(_ mode: String) async {
        do {
            try await rpc.setFollowUpMode(mode)
            followUpMode = mode
        } catch {
            show(notification: AppNotification(message: "Failed to apply follow-up mode: \(error.localizedDescription)", type: .error))
        }
    }

    func setAutoCompaction(_ enabled: Bool) async {
        do {
            try await rpc.setAutoCompaction(enabled: enabled)
            autoCompactionEnabled = enabled
        } catch {
            show(notification: AppNotification(message: "Failed to change auto-compaction: \(error.localizedDescription)", type: .error))
        }
    }

    func setAutoRetry(_ enabled: Bool) async {
        do {
            try await rpc.setAutoRetry(enabled: enabled)
            autoRetryEnabled = enabled
        } catch {
            show(notification: AppNotification(message: "Failed to change auto-retry: \(error.localizedDescription)", type: .error))
        }
    }

    func applyCustomModel(provider: String, modelId: String) async {
        let trimmedProvider = provider.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModelId = modelId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedProvider.isEmpty, !trimmedModelId.isEmpty else {
            show(notification: AppNotification(message: "Provider and Model ID are required", type: .warning))
            return
        }

        do {
            try await rpc.setModel(provider: trimmedProvider, modelId: trimmedModelId)

            if let existing = availableModels.first(where: { $0.id == trimmedModelId && $0.provider == trimmedProvider }) {
                currentModel = existing
            } else {
                let custom = AgentModel(
                    id: trimmedModelId,
                    name: trimmedModelId,
                    provider: trimmedProvider,
                    api: nil,
                    contextWindow: nil,
                    maxTokens: nil,
                    reasoning: nil,
                    cost: nil
                )
                availableModels.insert(custom, at: 0)
                currentModel = custom
            }

            show(notification: AppNotification(message: "Model applied: \(trimmedProvider)/\(trimmedModelId)", type: .success))
        } catch {
            show(notification: AppNotification(message: "Failed to apply model: \(error.localizedDescription)", type: .error))
        }
    }

    func reconnect() async {
        disconnect()
        await connect(piPath: piPath, workingDirectory: startupDirectory)
    }

    func updateFromGitHub() async {
        guard !isCheckingForUpdates else { return }
        isCheckingForUpdates = true
        defer { isCheckingForUpdates = false }

        do {
            let release = try await fetchLatestGitHubRelease()
            let currentVersion = normalizedVersionString(appVersion)
            let latestVersion = normalizedVersionString(release.tagName)

            guard isVersion(latestVersion, greaterThan: currentVersion) else {
                show(notification: AppNotification(message: "You already have the latest version (\(currentVersion))", type: .info))
                return
            }

            let download = release.assets?.first(where: { $0.name.lowercased().hasSuffix(".dmg") })?.browserDownloadURL
            let fallback = "https://github.com/Rrollan/PiChat/releases/latest/download/PiChat-macOS.dmg"
            guard let url = URL(string: download ?? fallback) else {
                show(notification: AppNotification(message: "Failed to build update link", type: .error))
                return
            }

            NSWorkspace.shared.open(url)
            show(notification: AppNotification(message: "Version \(latestVersion) found. Opening download…", type: .success))
        } catch {
            show(notification: AppNotification(message: "Failed to check updates: \(error.localizedDescription)", type: .error))
        }
    }

    private var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0.0.0"
    }

    private func fetchLatestGitHubRelease() async throws -> GitHubRelease {
        guard let url = URL(string: "https://api.github.com/repos/Rrollan/PiChat/releases/latest") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("PiChat", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }

    private func normalizedVersionString(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "v", with: "", options: .caseInsensitive, range: nil)
    }

    private func isVersion(_ lhs: String, greaterThan rhs: String) -> Bool {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(left.count, right.count)

        for i in 0..<count {
            let l = i < left.count ? left[i] : 0
            let r = i < right.count ? right[i] : 0
            if l != r { return l > r }
        }
        return false
    }

    func evaluateInstallLocationSuggestion() {
        let bundlePath = Bundle.main.bundleURL.path
        guard bundlePath.hasSuffix(".app") else {
            shouldSuggestMoveToApplications = false
            return
        }

        let isInApplications = bundlePath.hasPrefix("/Applications/") || bundlePath.contains("/Applications/")
        guard !isInApplications else {
            shouldSuggestMoveToApplications = false
            return
        }

        let dismissKey = "ui.dismissMoveToApplications.\(appVersion)"
        let dismissed = UserDefaults.standard.bool(forKey: dismissKey)
        shouldSuggestMoveToApplications = !dismissed
    }

    func dismissMoveToApplicationsSuggestion() {
        let dismissKey = "ui.dismissMoveToApplications.\(appVersion)"
        UserDefaults.standard.set(true, forKey: dismissKey)
        shouldSuggestMoveToApplications = false
    }

    func openApplicationsFolder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications", isDirectory: true))
    }

    func persistRuntimeSettings() {
        let defaults = UserDefaults.standard
        defaults.set(piPath, forKey: "pi.runtime.path")
        defaults.set(startupDirectory, forKey: "pi.runtime.startupDirectory")
        defaults.set(piConfigDirectory, forKey: "pi.runtime.configDirectory")

        defaults.set(cliNoSession, forKey: "pi.cli.noSession")
        defaults.set(cliProvider, forKey: "pi.cli.provider")
        defaults.set(cliModel, forKey: "pi.cli.model")
        defaults.set(cliApiKey, forKey: "pi.cli.apiKey")
        defaults.set(cliThinking, forKey: "pi.cli.thinking")
        defaults.set(cliModels, forKey: "pi.cli.models")
        defaults.set(cliSessionDir, forKey: "pi.cli.sessionDir")
        defaults.set(cliSession, forKey: "pi.cli.session")
        defaults.set(cliFork, forKey: "pi.cli.fork")
        defaults.set(cliTools, forKey: "pi.cli.tools")
        defaults.set(cliNoTools, forKey: "pi.cli.noTools")
        defaults.set(cliNoExtensions, forKey: "pi.cli.noExtensions")
        defaults.set(cliNoSkills, forKey: "pi.cli.noSkills")
        defaults.set(cliNoPromptTemplates, forKey: "pi.cli.noPromptTemplates")
        defaults.set(cliNoThemes, forKey: "pi.cli.noThemes")
        defaults.set(cliNoContextFiles, forKey: "pi.cli.noContextFiles")
        defaults.set(cliVerbose, forKey: "pi.cli.verbose")
        defaults.set(cliSystemPrompt, forKey: "pi.cli.systemPrompt")
        defaults.set(cliAppendSystemPrompt, forKey: "pi.cli.appendSystemPrompt")
        defaults.set(cliExtraArgs, forKey: "pi.cli.extraArgs")
    }

    func buildRpcLaunchArguments() -> [String] {
        var args: [String] = []

        if cliNoSession { args.append("--no-session") }
        if !cliProvider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            args += ["--provider", cliProvider.trimmingCharacters(in: .whitespacesAndNewlines)]
        }
        if !cliModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            args += ["--model", cliModel.trimmingCharacters(in: .whitespacesAndNewlines)]
        }
        if !cliApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            args += ["--api-key", cliApiKey.trimmingCharacters(in: .whitespacesAndNewlines)]
        }
        if !cliThinking.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            args += ["--thinking", cliThinking.trimmingCharacters(in: .whitespacesAndNewlines)]
        }
        if !cliModels.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            args += ["--models", cliModels.trimmingCharacters(in: .whitespacesAndNewlines)]
        }
        if !cliSessionDir.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            args += ["--session-dir", cliSessionDir.trimmingCharacters(in: .whitespacesAndNewlines)]
        }
        if !cliSession.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            args += ["--session", cliSession.trimmingCharacters(in: .whitespacesAndNewlines)]
        }
        if !cliFork.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            args += ["--fork", cliFork.trimmingCharacters(in: .whitespacesAndNewlines)]
        }
        if !cliTools.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            args += ["--tools", cliTools.trimmingCharacters(in: .whitespacesAndNewlines)]
        }

        if cliNoTools { args.append("--no-tools") }
        if cliNoExtensions { args.append("--no-extensions") }
        if cliNoSkills { args.append("--no-skills") }
        if cliNoPromptTemplates { args.append("--no-prompt-templates") }
        if cliNoThemes { args.append("--no-themes") }
        if cliNoContextFiles { args.append("--no-context-files") }
        if cliVerbose { args.append("--verbose") }

        if !cliSystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            args += ["--system-prompt", cliSystemPrompt]
        }
        if !cliAppendSystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            args += ["--append-system-prompt", cliAppendSystemPrompt]
        }

        let extra = cliExtraArgs
            .split(separator: " ")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        args += extra

        return args
    }

    func applySettingsFormToJSON() {
        var root: [String: Any] = [:]

        root["defaultProvider"] = sDefaultProvider
        root["defaultModel"] = sDefaultModel
        root["defaultThinkingLevel"] = sDefaultThinkingLevel
        root["hideThinkingBlock"] = sHideThinkingBlock
        root["thinkingBudgets"] = [
            "minimal": Int(sThinkingMinimal) ?? 1024,
            "low": Int(sThinkingLow) ?? 4096,
            "medium": Int(sThinkingMedium) ?? 10240,
            "high": Int(sThinkingHigh) ?? 32768
        ]
        root["theme"] = sTheme
        root["quietStartup"] = sQuietStartup
        root["collapseChangelog"] = sCollapseChangelog
        root["enableInstallTelemetry"] = sEnableInstallTelemetry
        root["doubleEscapeAction"] = sDoubleEscapeAction
        root["treeFilterMode"] = sTreeFilterMode
        root["editorPaddingX"] = Int(sEditorPaddingX) ?? 0
        root["autocompleteMaxVisible"] = Int(sAutocompleteMaxVisible) ?? 5
        root["showHardwareCursor"] = sShowHardwareCursor

        root["compaction"] = [
            "enabled": sCompactionEnabled,
            "reserveTokens": Int(sCompactionReserveTokens) ?? 16384,
            "keepRecentTokens": Int(sCompactionKeepRecentTokens) ?? 20000
        ]
        root["branchSummary"] = [
            "reserveTokens": Int(sBranchSummaryReserveTokens) ?? 16384,
            "skipPrompt": sBranchSummarySkipPrompt
        ]
        root["retry"] = [
            "enabled": sRetryEnabled,
            "maxRetries": Int(sRetryMaxRetries) ?? 3,
            "baseDelayMs": Int(sRetryBaseDelayMs) ?? 2000,
            "maxDelayMs": Int(sRetryMaxDelayMs) ?? 60000
        ]

        root["steeringMode"] = sSteeringMode
        root["followUpMode"] = sFollowUpMode
        root["transport"] = sTransport

        root["terminal"] = [
            "showImages": sTerminalShowImages,
            "imageWidthCells": Int(sTerminalImageWidthCells) ?? 60,
            "clearOnShrink": sTerminalClearOnShrink
        ]
        root["images"] = [
            "autoResize": sImagesAutoResize,
            "blockImages": sImagesBlockImages
        ]

        root["shellPath"] = sShellPath
        root["shellCommandPrefix"] = sShellCommandPrefix
        root["npmCommand"] = csvToArray(sNpmCommand)
        root["sessionDir"] = sSessionDir
        root["enabledModels"] = csvToArray(sEnabledModels)
        root["markdown"] = ["codeBlockIndent": sMarkdownCodeBlockIndent]

        root["packages"] = csvToArray(sPackages)
        root["extensions"] = csvToArray(sExtensions)
        root["skills"] = csvToArray(sSkills)
        root["prompts"] = csvToArray(sPrompts)
        root["themes"] = csvToArray(sThemes)
        root["enableSkillCommands"] = sEnableSkillCommands

        settingsJSONText = configManager.prettyPrinted(root)
    }

    func applySettingsFormFromJSON() {
        guard let settingsData = settingsJSONText.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: settingsData) as? [String: Any] else {
            return
        }

        sDefaultProvider = json["defaultProvider"] as? String ?? ""
        sDefaultModel = json["defaultModel"] as? String ?? ""
        sDefaultThinkingLevel = json["defaultThinkingLevel"] as? String ?? "off"
        sHideThinkingBlock = json["hideThinkingBlock"] as? Bool ?? false

        let budgets = json["thinkingBudgets"] as? [String: Any] ?? [:]
        sThinkingMinimal = "\(budgets["minimal"] as? Int ?? 1024)"
        sThinkingLow = "\(budgets["low"] as? Int ?? 4096)"
        sThinkingMedium = "\(budgets["medium"] as? Int ?? 10240)"
        sThinkingHigh = "\(budgets["high"] as? Int ?? 32768)"

        sTheme = json["theme"] as? String ?? "dark"
        sQuietStartup = json["quietStartup"] as? Bool ?? false
        sCollapseChangelog = json["collapseChangelog"] as? Bool ?? false
        sEnableInstallTelemetry = json["enableInstallTelemetry"] as? Bool ?? true
        sDoubleEscapeAction = json["doubleEscapeAction"] as? String ?? "tree"
        sTreeFilterMode = json["treeFilterMode"] as? String ?? "default"
        sEditorPaddingX = "\(json["editorPaddingX"] as? Int ?? 0)"
        sAutocompleteMaxVisible = "\(json["autocompleteMaxVisible"] as? Int ?? 5)"
        sShowHardwareCursor = json["showHardwareCursor"] as? Bool ?? false

        let compaction = json["compaction"] as? [String: Any] ?? [:]
        sCompactionEnabled = compaction["enabled"] as? Bool ?? true
        sCompactionReserveTokens = "\(compaction["reserveTokens"] as? Int ?? 16384)"
        sCompactionKeepRecentTokens = "\(compaction["keepRecentTokens"] as? Int ?? 20000)"

        let branch = json["branchSummary"] as? [String: Any] ?? [:]
        sBranchSummaryReserveTokens = "\(branch["reserveTokens"] as? Int ?? 16384)"
        sBranchSummarySkipPrompt = branch["skipPrompt"] as? Bool ?? false

        let retry = json["retry"] as? [String: Any] ?? [:]
        sRetryEnabled = retry["enabled"] as? Bool ?? true
        sRetryMaxRetries = "\(retry["maxRetries"] as? Int ?? 3)"
        sRetryBaseDelayMs = "\(retry["baseDelayMs"] as? Int ?? 2000)"
        sRetryMaxDelayMs = "\(retry["maxDelayMs"] as? Int ?? 60000)"

        sSteeringMode = json["steeringMode"] as? String ?? "one-at-a-time"
        sFollowUpMode = json["followUpMode"] as? String ?? "one-at-a-time"
        sTransport = json["transport"] as? String ?? "sse"

        let terminal = json["terminal"] as? [String: Any] ?? [:]
        sTerminalShowImages = terminal["showImages"] as? Bool ?? true
        sTerminalImageWidthCells = "\(terminal["imageWidthCells"] as? Int ?? 60)"
        sTerminalClearOnShrink = terminal["clearOnShrink"] as? Bool ?? false

        let images = json["images"] as? [String: Any] ?? [:]
        sImagesAutoResize = images["autoResize"] as? Bool ?? true
        sImagesBlockImages = images["blockImages"] as? Bool ?? false

        sShellPath = json["shellPath"] as? String ?? ""
        sShellCommandPrefix = json["shellCommandPrefix"] as? String ?? ""
        sNpmCommand = arrayToCSV(json["npmCommand"] as? [String] ?? [])
        sSessionDir = json["sessionDir"] as? String ?? ""
        sEnabledModels = arrayToCSV(json["enabledModels"] as? [String] ?? [])

        let markdown = json["markdown"] as? [String: Any] ?? [:]
        sMarkdownCodeBlockIndent = markdown["codeBlockIndent"] as? String ?? "  "

        sPackages = arrayToCSV(json["packages"] as? [String] ?? [])
        sExtensions = arrayToCSV(json["extensions"] as? [String] ?? [])
        sSkills = arrayToCSV(json["skills"] as? [String] ?? [])
        sPrompts = arrayToCSV(json["prompts"] as? [String] ?? [])
        sThemes = arrayToCSV(json["themes"] as? [String] ?? [])
        sEnableSkillCommands = json["enableSkillCommands"] as? Bool ?? true

        steeringMode = sSteeringMode
        followUpMode = sFollowUpMode
        autoCompactionEnabled = sCompactionEnabled
        autoRetryEnabled = sRetryEnabled
    }

    private func csvToArray(_ text: String) -> [String] {
        text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func arrayToCSV(_ value: [String]) -> String {
        value.joined(separator: ", ")
    }

    func loadConfigFiles() {
        settingsJSONText = configManager.readRawFile(named: "settings.json", defaultContent: "{}")
        modelsJSONText = configManager.readRawFile(named: "models.json", defaultContent: "{\n  \"providers\": {}\n}")
        authJSONText = configManager.readRawFile(named: "auth.json", defaultContent: "{}")
        authEntries = configManager.loadAuthEntries()
        mcpServers = configManager.loadMCPServers()

        applySettingsFormFromJSON()
    }

    func saveSettingsJSON() {
        do {
            _ = try JSONSerialization.jsonObject(with: Data(settingsJSONText.utf8))
            try configManager.writeRawFile(named: "settings.json", content: settingsJSONText)
            applySettingsFormFromJSON()
            show(notification: AppNotification(message: "settings.json saved", type: .success))
        } catch {
            show(notification: AppNotification(message: "settings.json error: \(error.localizedDescription)", type: .error))
        }
    }

    func saveSettingsFromForm() {
        applySettingsFormToJSON()
        saveSettingsJSON()
    }

    func saveModelsJSON() {
        do {
            _ = try JSONSerialization.jsonObject(with: Data(modelsJSONText.utf8))
            try configManager.writeRawFile(named: "models.json", content: modelsJSONText)
            show(notification: AppNotification(message: "models.json saved", type: .success))
            Task { await reconnect() }
        } catch {
            show(notification: AppNotification(message: "models.json error: \(error.localizedDescription)", type: .error))
        }
    }

    func saveAuthJSON() {
        do {
            _ = try JSONSerialization.jsonObject(with: Data(authJSONText.utf8))
            try configManager.writeRawFile(named: "auth.json", content: authJSONText)
            authEntries = configManager.loadAuthEntries()
            show(notification: AppNotification(message: "auth.json saved", type: .success))
            Task { await reconnect() }
        } catch {
            show(notification: AppNotification(message: "auth.json error: \(error.localizedDescription)", type: .error))
        }
    }

    func upsertAccount(provider: String, key: String) {
        let p = provider.trimmingCharacters(in: .whitespacesAndNewlines)
        let k = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !p.isEmpty, !k.isEmpty else {
            show(notification: AppNotification(message: "Provider and key are required", type: .warning))
            return
        }

        do {
            try configManager.upsertApiKey(provider: p, key: k)
            loadConfigFiles()
            show(notification: AppNotification(message: "Account updated: \(p)", type: .success))
        } catch {
            show(notification: AppNotification(message: "Failed to save account: \(error.localizedDescription)", type: .error))
        }
    }

    func removeAccount(provider: String) {
        do {
            try configManager.removeAuth(provider: provider)
            loadConfigFiles()
            show(notification: AppNotification(message: "Account removed: \(provider)", type: .success))
        } catch {
            show(notification: AppNotification(message: "Failed to remove account: \(error.localizedDescription)", type: .error))
        }
    }

    func addCustomProviderModel(provider: String,
                                baseUrl: String,
                                api: String,
                                apiKey: String,
                                modelId: String,
                                modelName: String,
                                reasoning: Bool,
                                supportsImages: Bool) {
        do {
            try configManager.addCustomModel(providerId: provider,
                                             baseUrl: baseUrl,
                                             api: api,
                                             apiKey: apiKey,
                                             modelId: modelId,
                                             modelName: modelName,
                                             reasoning: reasoning,
                                             supportsImages: supportsImages)
            loadConfigFiles()
            show(notification: AppNotification(message: "Model added: \(provider)/\(modelId)", type: .success))
        } catch {
            show(notification: AppNotification(message: "Failed to add model: \(error.localizedDescription)", type: .error))
        }
    }

    func show(notification: AppNotification) {
        self.notification = notification
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if self.notification?.id == notification.id {
                self.notification = nil
            }
        }
    }

    func acknowledgeShortcut(_ shortcut: String) {
        keyFeedbackTask?.cancel()
        keyFeedbackText = shortcut

        keyFeedbackTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            self?.keyFeedbackText = nil
        }
    }

    private func beginBusyAction(_ text: String) {
        busyActionDepth += 1
        busyActionText = text
    }

    private func endBusyAction() {
        busyActionDepth = max(0, busyActionDepth - 1)
        if busyActionDepth == 0 {
            busyActionText = nil
        }
    }

    // MARK: - File Handling

    func addFile(url: URL) {
        let mime = mimeType(for: url)
        var att = FileAttachment(url: url, name: url.lastPathComponent, mimeType: mime)
        if let data = try? Data(contentsOf: url) {
            att = FileAttachment(url: url, name: url.lastPathComponent, mimeType: mime,
                                  base64Data: data.base64EncodedString())
        }
        attachedFiles.append(att)
    }

    func removeAttachment(id: UUID) {
        attachedFiles.removeAll { $0.id == id }
    }

    private func mimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "pdf": return "application/pdf"
        default: return "text/plain"
        }
    }
}

// MARK: - Helper Models

struct AppNotification: Identifiable {
    let id = UUID()
    let message: String
    let type: NotificationType

    enum NotificationType { case info, warning, error, success }
}

struct ExtensionUIRequest: Identifiable {
    let id: String
    let method: String
    let title: String?
    let message: String?
    let options: [String]?
    let placeholder: String?
    let prefill: String?
}

struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: String
    let assets: [GitHubReleaseAsset]?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }
}

struct GitHubReleaseAsset: Decodable {
    let name: String
    let browserDownloadURL: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}
