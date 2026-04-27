import Foundation
import Combine
import SwiftUI
import AppKit
import UniformTypeIdentifiers

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

struct PastedContent: Identifiable {
    let id = UUID()
    let content: String
    let timestamp: Date = Date()
    var wordCount: Int { content.split(whereSeparator: { $0.isWhitespace }).count }
    var title: String { "Pasted text" }
}

struct ModelProviderGroup: Identifiable {
    let id: String
    let provider: String
    let models: [AgentModel]
    let isConnected: Bool
}

extension AgentModel {
    var modelKey: String { "\(provider)/\(id)" }
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
    @Published var hiddenModelKeys: [String] = []
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
    @Published var oauthAuthURLString: String?
    @Published var oauthAuthInstructions: String?
    @Published var oauthVerificationCode: String?
    @Published var oauthPromptMessage: String?
    @Published var oauthPromptPlaceholder: String?
    @Published var oauthPromptAllowsEmpty: Bool = false
    @Published var oauthPromptInput: String = ""

    // MARK: Keyboard / Action Feedback
    @Published var keyFeedbackText: String?
    @Published var busyActionText: String?

    // MARK: Extension UI
    @Published var pendingUIRequest: ExtensionUIRequest?

    // MARK: Input
    @Published var inputText: String = ""
    @Published var attachedFiles: [FileAttachment] = []
    @Published var pastedContents: [PastedContent] = []

    // MARK: Pi Runtime & Config
    @Published var piPath: String
    @Published var startupDirectory: String
    @Published var piConfigDirectory: String
    @Published var piRuntimeStatusText: String = "Runtime not resolved"
    @Published var piRuntimeAutoUpdatesEnabled: Bool
    @Published var isCheckingPiRuntimeUpdates = false
    @Published var settingsJSONText: String = "{}"
    @Published var modelsJSONText: String = "{}"
    @Published var authJSONText: String = "{}"
    @Published var mcpJSONText: String = "{}"
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

    // MARK: Account Profiles / Failover
    @Published var accountProfiles: [PiAccountProfile] = []
    @Published var activeAccountProfileID: String?
    @Published var autoAccountFailoverEnabled: Bool
    private var skippedAccountProfileIDs = Set<String>()

    // MARK: App Update
    @Published var isCheckingForUpdates = false
    @Published var availableAppUpdate: AppUpdateInfo?
    private var dismissedAppUpdateTagThisLaunch: String?

    // MARK: Browser Assistant
    @Published var browserExtensionId: String = ""
    @Published var browserPairingToken: String = ""
    @Published var browserBridgeStatusText: String = "Not configured"
    @Published var browserBridgeManifestPath: String = NativeMessagingInstaller.chromeManifestPath.path
    @Published var browserBridgeAllowedOrigin: String = "Not configured"
    @Published var browserBridgeLastSeenText: String = "Never"
    @Published var browserBridgePairingStatusText: String = "Pairing token not installed"
    @Published var browserToolsEnabled: Bool = true
    @Published var browserToolsStatusText: String = "Enabled"
    @Published var isInstallingBrowserBridge = false

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
    private let piRuntimeManager = PiRuntimeManager()

    init() {
        let defaults = UserDefaults.standard
        self.piPath = defaults.string(forKey: "pi.runtime.path") ?? "pi"
        self.startupDirectory = defaults.string(forKey: "pi.runtime.startupDirectory") ?? NSHomeDirectory()
        self.piConfigDirectory = defaults.string(forKey: "pi.runtime.configDirectory") ?? PiConfigManager.defaultConfigDir()
        self.piRuntimeAutoUpdatesEnabled = defaults.object(forKey: "pi.runtime.autoUpdatesEnabled") as? Bool ?? true
        self.activeAccountProfileID = defaults.string(forKey: "pi.account.activeProfileID")
        self.autoAccountFailoverEnabled = defaults.object(forKey: "pi.account.autoFailoverEnabled") as? Bool ?? true
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
        self.hiddenModelKeys = defaults.stringArray(forKey: "pi.hiddenModelKeys") ?? []
        self.browserToolsEnabled = true
        self.browserExtensionId = defaults.string(forKey: "browser.extensionId") ?? ""
        self.browserPairingToken = defaults.string(forKey: "browser.pairingToken") ?? ""
        refreshBrowserBridgeStatus()
        setupEventHandling()
        loadConfigFiles()
        loadAccountProfiles()
        refreshPiRuntimeStatus()
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

    private func clearConversationTransientState(clearMessages: Bool = false) {
        if clearMessages {
            messages.removeAll()
        }
        activeTools.removeAll()
        activeToolCallMap.removeAll()
        currentAssistantMessageIndex = nil
        isStreaming = false
        isWaitingForResponse = false
        isRetrying = false
        retryMessage = nil
    }

    private func currentAssistantIndexIfValid() -> Int? {
        guard let idx = currentAssistantMessageIndex,
              messages.indices.contains(idx),
              messages[idx].role == .assistant else {
            currentAssistantMessageIndex = nil
            return nil
        }
        return idx
    }

    private func activeToolIndex(for toolCallId: String) -> Int? {
        if let idx = activeToolCallMap[toolCallId],
           activeTools.indices.contains(idx),
           activeTools[idx].id == toolCallId {
            return idx
        }

        guard let idx = activeTools.firstIndex(where: { $0.id == toolCallId }) else {
            activeToolCallMap.removeValue(forKey: toolCallId)
            return nil
        }

        activeToolCallMap[toolCallId] = idx
        return idx
    }

    private func rebuildActiveToolCallMap() {
        activeToolCallMap = Dictionary(uniqueKeysWithValues: activeTools.enumerated().map { ($0.element.id, $0.offset) })
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

        let selectedRuntime = configurePiRuntime(for: resolvedPiPath)
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
            if selectedRuntime?.source == .userUpdated, let bundledRuntime = piRuntimeManager.bundledRuntime() {
                applyPiRuntime(bundledRuntime)
                do {
                    try await rpc.start()
                    isConnected = true
                    show(notification: AppNotification(message: "Updated pi runtime failed; using bundled pi \(bundledRuntime.version).", type: .error))
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    await loadInitialState()
                } catch {
                    connectionError = "Updated pi runtime failed, and bundled fallback also failed: \(error.localizedDescription)"
                }
            } else {
                connectionError = error.localizedDescription
            }
        }
        isStarting = false
    }

    @discardableResult
    private func configurePiRuntime(for requestedPath: String) -> PiRuntimeInstallation? {
        let trimmed = requestedPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let wantsDefaultPi = trimmed.isEmpty || trimmed == "pi"

        rpc.piCliScriptPath = nil
        rpc.piNodePath = nil
        rpc.piPath = wantsDefaultPi ? "pi" : requestedPath

        guard wantsDefaultPi, let runtime = piRuntimeManager.activeRuntime() else {
            piRuntimeStatusText = wantsDefaultPi ? "Using pi from PATH" : "Using external pi: \(requestedPath)"
            return nil
        }

        applyPiRuntime(runtime)
        return runtime
    }

    private func applyPiRuntime(_ runtime: PiRuntimeInstallation) {
        rpc.piPath = "pi"
        rpc.piNodePath = runtime.nodePath.path
        rpc.piCliScriptPath = runtime.cliPath.path
        piRuntimeStatusText = "\(runtime.displayName) · \(runtime.source == .bundled ? "app bundle" : "Application Support")"
    }

    func refreshPiRuntimeStatus() {
        configurePiRuntime(for: piPath)
    }

    func disconnect(clearMessages: Bool = true) {
        responseWatchdogTask?.cancel()
        rpc.stop()
        isConnected = false
        clearConversationTransientState(clearMessages: clearMessages)
    }

    func changeProject(newDirectory: String) async {
        disconnect()
        startupDirectory = newDirectory
        persistRuntimeSettings()
        await connect(piPath: piPath, workingDirectory: newDirectory)
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
            if let idx = currentAssistantMessageIndex, messages.indices.contains(idx), messages[idx].role == .assistant {
                messages[idx].isStreaming = true
            } else {
                let msg = ChatMessage(role: .assistant, text: "", isStreaming: true)
                messages.append(msg)
                currentAssistantMessageIndex = messages.count - 1
            }

        case .agentEnd:
            isWaitingForResponse = false
            isStreaming = false
            if let idx = currentAssistantIndexIfValid() {
                messages[idx].isStreaming = false
            }
            currentAssistantMessageIndex = nil
            // Refresh stats
            Task { await refreshStats() }

        case .messageUpdate(let delta):
            guard let idx = currentAssistantIndexIfValid() else { return }
            switch delta.type {
            case "text_delta":
                messages[idx].text += delta.delta ?? ""
            case "thinking_delta":
                messages[idx].thinkingText += delta.delta ?? ""
                messages[idx].showThinking = true
            default: break
            }

        case .toolExecutionStart(let tcId, let tn, let args):
            let argsText = args.map { String(describing: $0.value) } ?? ""
            let tool = ToolCall(id: tcId, name: tn, args: argsText, output: "", isError: false, isRunning: true)
            activeTools.append(tool)
            activeToolCallMap[tcId] = activeTools.count - 1

            // Also add to current message's tool calls
            if let idx = currentAssistantIndexIfValid() {
                messages[idx].toolCalls.append(tool)
            }

        case .toolExecutionUpdate(let tcId, _, let partial):
            if let i = activeToolIndex(for: tcId) {
                activeTools[i].output = partial
            }
            // Update in message too
            if let msgIdx = currentAssistantIndexIfValid(),
               let tIdx = messages[msgIdx].toolCalls.firstIndex(where: { $0.id == tcId }) {
                messages[msgIdx].toolCalls[tIdx].output = partial
            }

        case .toolExecutionEnd(let tcId, let toolName, let result, let isErr):
            let completedToolIndex = activeToolIndex(for: tcId)
            if let i = completedToolIndex {
                activeTools[i].output = result
                activeTools[i].isError = isErr
                activeTools[i].isRunning = false
            }
            if let msgIdx = currentAssistantIndexIfValid(),
               let tIdx = messages[msgIdx].toolCalls.firstIndex(where: { $0.id == tcId }) {
                messages[msgIdx].toolCalls[tIdx].output = result
                messages[msgIdx].toolCalls[tIdx].isError = isErr
                messages[msgIdx].toolCalls[tIdx].isRunning = false
            }
            let completedTool = completedToolIndex.map { activeTools[$0] } ?? activeTools.first(where: { $0.id == tcId })
            let argsText = completedTool?.args ?? ""
            refreshResourcesAfterAgentInstallIfNeeded(toolName: completedTool?.name ?? toolName, args: argsText, output: result, isError: isErr)

            activeToolCallMap.removeValue(forKey: tcId)
            // Remove from active after short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.activeTools.removeAll { $0.id == tcId && !$0.isRunning }
                self.rebuildActiveToolCallMap()
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

        case .processTerminated(let message):
            isConnected = false
            isStreaming = false
            isWaitingForResponse = false
            logAgentError(message, context: "pi_process")
            if currentAssistantMessageIndex == nil {
                show(notification: AppNotification(message: "pi stopped — will reconnect on next message", type: .warning))
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
            if let idx = self.currentAssistantMessageIndex, self.messages.indices.contains(idx), self.messages[idx].text.isEmpty, self.messages[idx].thinkingText.isEmpty {
                self.messages[idx].isStreaming = false
                self.currentAssistantMessageIndex = nil
            }
            self.isWaitingForResponse = false
        }
    }

    // MARK: - Actions

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !attachedFiles.isEmpty || !pastedContents.isEmpty else { return }

        guard await ensurePiIsRunningBeforePrompt() else { return }

        let pastedText = pastedContents.map { item in
            "\n\n--- Pasted content (\(item.wordCount) words) ---\n\(item.content)"
        }.joined()
        let promptText = text + pastedText
        let displayText = text.isEmpty && !pastedContents.isEmpty ? "Pasted content attached" : text

        let userMsg = ChatMessage(role: .user, text: displayText, attachments: attachedFiles)
        messages.append(userMsg)

        let assistantPlaceholder = ChatMessage(role: .assistant, text: "", isStreaming: true)
        messages.append(assistantPlaceholder)
        currentAssistantMessageIndex = messages.count - 1

        let images: [RPCImage] = attachedFiles.compactMap { att in
            guard att.isImage, let b64 = att.base64Data else { return nil }
            return RPCImage(data: b64, mimeType: att.mimeType)
        }

        inputText = ""
        attachedFiles = []
        pastedContents = []
        isWaitingForResponse = true
        startResponseWatchdog()

        let assistantIndex = currentAssistantMessageIndex
        do {
            try await rpc.prompt(promptText, images: images)
        } catch {
            responseWatchdogTask?.cancel()
            if isPiNotRunningError(error.localizedDescription), await reconnectAndRetryPrompt(promptText: promptText, images: images, assistantIndex: assistantIndex) {
                return
            }
            if await retryPromptAfterAccountFailover(
                promptText: promptText,
                images: images,
                failedError: error.localizedDescription,
                assistantIndex: assistantIndex
            ) {
                return
            }
            isWaitingForResponse = false
            if let idx = assistantIndex, messages.indices.contains(idx), messages[idx].text.isEmpty, messages[idx].thinkingText.isEmpty {
                messages[idx].isStreaming = false
            }
            currentAssistantMessageIndex = nil
            logAgentError(error.localizedDescription, context: "prompt_send")
            addSystemMessage("❌ \(error.localizedDescription)")
        }
    }

    private func ensurePiIsRunningBeforePrompt() async -> Bool {
        if rpc.isRunning { return true }
        isConnected = false
        show(notification: AppNotification(message: "pi stopped. Reconnecting…", type: .warning))
        await connect(piPath: piPath, workingDirectory: startupDirectory)
        if rpc.isRunning { return true }
        let message = connectionError ?? "pi is not running"
        logAgentError(message, context: "prompt_preflight")
        addSystemMessage("❌ \(message)")
        show(notification: AppNotification(message: message, type: .error))
        return false
    }

    private func reconnectAndRetryPrompt(promptText: String, images: [RPCImage], assistantIndex: Int?) async -> Bool {
        logAgentError("pi stopped during prompt send; reconnecting", context: "prompt_reconnect_retry")
        show(notification: AppNotification(message: "pi stopped. Reconnecting and retrying…", type: .warning))
        disconnect(clearMessages: false)
        await connect(piPath: piPath, workingDirectory: startupDirectory)
        guard rpc.isRunning else { return false }
        if let idx = assistantIndex, messages.indices.contains(idx) {
            messages[idx].isStreaming = true
            currentAssistantMessageIndex = idx
        }
        isWaitingForResponse = true
        startResponseWatchdog()
        do {
            try await rpc.prompt(promptText, images: images)
            return true
        } catch {
            logAgentError(error.localizedDescription, context: "prompt_reconnect_retry_failed")
            return false
        }
    }

    private func isPiNotRunningError(_ message: String) -> Bool {
        message.lowercased().contains("pi is not running") || message.lowercased().contains("process terminated")
    }

    private func retryPromptAfterAccountFailover(promptText: String, images: [RPCImage], failedError: String, assistantIndex: Int?) async -> Bool {
        guard autoAccountFailoverEnabled, isQuotaOrRateLimitError(failedError) else { return false }
        guard let nextProfile = nextAccountProfileForFailover() else { return false }

        if let activeAccountProfileID {
            skippedAccountProfileIDs.insert(activeAccountProfileID)
        }
        activeAccountProfileID = nextProfile.id
        persistRuntimeSettings()

        let previousModel = currentModel
        addSystemMessage("↪️ Limit reached. Switching to \(nextProfile.name) (\(nextProfile.provider)) and retrying…")
        show(notification: AppNotification(message: "Switching account: \(nextProfile.name)", type: .warning))

        disconnect(clearMessages: false)
        await connect(piPath: piPath, workingDirectory: startupDirectory)
        if let previousModel, normalizeProviderID(previousModel.provider) == normalizeProviderID(nextProfile.provider) {
            try? await rpc.setModel(provider: previousModel.provider, modelId: previousModel.id)
            currentModel = previousModel
        }

        guard isConnected else { return false }
        if let idx = assistantIndex, messages.indices.contains(idx) {
            messages[idx].isStreaming = true
            currentAssistantMessageIndex = idx
        }
        isWaitingForResponse = true
        startResponseWatchdog()

        do {
            try await rpc.prompt(promptText, images: images)
            return true
        } catch {
            logAgentError(error.localizedDescription, context: "prompt_failover_retry")
            return false
        }
    }

    private func nextAccountProfileForFailover() -> PiAccountProfile? {
        let activeID = activeAccountProfileID
        let preferredProvider = activeAccountProfile?.provider ?? currentModel?.provider ?? cliProvider
        let enabled = accountProfiles.filter { profile in
            profile.isEnabled && profile.id != activeID && !skippedAccountProfileIDs.contains(profile.id)
        }
        if !preferredProvider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let sameProvider = enabled.first(where: { normalizeProviderID($0.provider) == normalizeProviderID(preferredProvider) }) {
            return sameProvider
        }
        return enabled.first
    }

    private func isQuotaOrRateLimitError(_ message: String) -> Bool {
        let lowered = message.lowercased()
        return [
            "rate limit", "ratelimit", "too many requests", "429", "quota", "insufficient_quota",
            "resource_exhausted", "limit exceeded", "usage limit", "capacity", "overloaded"
        ].contains { lowered.contains($0) }
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
        oauthAuthURLString = nil
        oauthAuthInstructions = nil
        oauthVerificationCode = nil
        oauthPromptMessage = nil
        oauthPromptPlaceholder = nil
        oauthPromptAllowsEmpty = false
        oauthPromptInput = ""

        defer {
            isOAuthLoginRunning = false
            oauthHelperInputHandle = nil
            oauthHelperProcess = nil
        }

        do {
            try await runOAuthLogin(providerId: providerId)
            loadConfigFiles()
            oauthAuthURLString = nil
            oauthAuthInstructions = nil
            oauthVerificationCode = nil
            oauthPromptMessage = nil
            oauthPromptPlaceholder = nil
            oauthPromptAllowsEmpty = false
            oauthPromptInput = ""
            oauthLoginStatusText = "Authentication completed: \(providerId). Refreshing models…"
            if isConnected {
                await reconnect()
            }
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
        guard oauthPromptAllowsEmpty || !text.isEmpty else { return }

        let line = text + "\n"
        if let data = line.data(using: .utf8) {
            handle.write(data)
            oauthPromptInput = ""
            oauthLoginStatusText = "Submitted verification input…"
            oauthPromptMessage = nil
            oauthPromptPlaceholder = nil
            oauthPromptAllowsEmpty = false
        }
    }

    func cancelOAuthLogin() {
        oauthHelperProcess?.terminate()
        oauthHelperProcess = nil
        oauthHelperInputHandle = nil
        isOAuthLoginRunning = false
        oauthAuthURLString = nil
        oauthAuthInstructions = nil
        oauthVerificationCode = nil
        oauthPromptMessage = nil
        oauthPromptPlaceholder = nil
        oauthPromptAllowsEmpty = false
        oauthLoginStatusText = "Authentication cancelled"
    }

    private func runOAuthLogin(providerId: String) async throws {
        let script = """
import readline from 'node:readline';
import { pathToFileURL } from 'node:url';

const authStorageModule = process.env.PI_AUTH_STORAGE_MODULE;
if (!authStorageModule) throw new Error('Pi AuthStorage module was not found. Use the bundled pi runtime or install pi globally.');
const { AuthStorage } = await import(pathToFileURL(authStorageModule).href);

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
      send({ type: 'prompt', message: prompt?.message ?? 'Enter the requested value', placeholder: prompt?.placeholder ?? '', allowEmpty: Boolean(prompt?.allowEmpty) });
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

        let runtime = piRuntimeManager.activeRuntime()
        let nodeExecutable = runtime?.nodePath.path ?? resolveNodeExecutable()
        let authStoragePath = runtime?.authStoragePath.path ?? resolveGlobalAuthStorageModule()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: nodeExecutable)
        process.arguments = ["--input-type=module", "-e", script, providerId, authPath]
        var env = ProcessInfo.processInfo.environment
        if let authStoragePath { env["PI_AUTH_STORAGE_MODULE"] = authStoragePath }
        if let runtime { env["PATH"] = "\(runtime.nodePath.deletingLastPathComponent().path):\(env["PATH"] ?? "")" }
        process.environment = env

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

        let status = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int32, Error>) in
            process.terminationHandler = { proc in
                continuation.resume(returning: proc.terminationStatus)
            }

            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
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

    private func resolveGlobalAuthStorageModule() -> String? {
        let candidates = [
            "/opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/dist/core/auth-storage.js",
            "/usr/local/lib/node_modules/@mariozechner/pi-coding-agent/dist/core/auth-storage.js"
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    private func handleOAuthHelperEventLine(_ line: String) {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = obj["type"] as? String else { return }

        switch type {
        case "auth":
            let instructions = (obj["instructions"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            oauthAuthInstructions = instructions?.isEmpty == false ? instructions : nil
            oauthVerificationCode = extractVerificationCode(from: instructions)

            if let urlString = obj["url"] as? String, let url = URL(string: urlString), !urlString.isEmpty {
                oauthAuthURLString = urlString
                NSWorkspace.shared.open(url)
                if let code = oauthVerificationCode {
                    oauthLoginStatusText = "Browser opened. Enter code \(code) on GitHub."
                } else if let instructions, !instructions.isEmpty {
                    oauthLoginStatusText = instructions
                } else {
                    oauthLoginStatusText = "Browser opened. Complete authentication, then paste verification data below if requested."
                }
            }

        case "progress":
            if let message = obj["message"] as? String, !message.isEmpty {
                oauthLoginStatusText = message
            }

        case "prompt", "manual":
            if let message = obj["message"] as? String, !message.isEmpty {
                oauthPromptMessage = message
                oauthPromptPlaceholder = obj["placeholder"] as? String
                oauthPromptAllowsEmpty = (obj["allowEmpty"] as? Bool) ?? false
                oauthLoginStatusText = message
            }

        case "done":
            oauthAuthURLString = nil
            oauthAuthInstructions = nil
            oauthVerificationCode = nil
            oauthPromptMessage = nil
            oauthPromptPlaceholder = nil
            oauthPromptAllowsEmpty = false

        case "error":
            if let message = obj["message"] as? String, !message.isEmpty {
                oauthLoginStatusText = message
                oauthPromptMessage = message
            }

        default:
            break
        }
    }

    private func extractVerificationCode(from instructions: String?) -> String? {
        guard let instructions else { return nil }
        let patterns = [
            #"(?i)code:\s*([A-Z0-9-]{4,})"#,
            #"\b([A-Z0-9]{4}-[A-Z0-9]{4})\b"#,
            #"\b([A-Z0-9]{8})\b"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(instructions.startIndex..<instructions.endIndex, in: instructions)
            if let match = regex.firstMatch(in: instructions, range: range), match.numberOfRanges > 1,
               let codeRange = Range(match.range(at: 1), in: instructions) {
                return String(instructions[codeRange])
            }
        }
        return nil
    }

    func copyOAuthVerificationCode() {
        guard let code = oauthVerificationCode else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        show(notification: AppNotification(message: "Verification code copied", type: .success))
    }

    func openOAuthAuthURL() {
        guard let urlString = oauthAuthURLString, let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
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

    func refreshModels() async {
        availableModels = (try? await rpc.getAvailableModels()) ?? availableModels
    }

    func startNewSession() async {
        beginBusyAction("Creating new session…")
        defer { endBusyAction() }

        do {
            try await rpc.newSession()
            clearConversationTransientState(clearMessages: true)
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

    var activeAccountProfile: PiAccountProfile? {
        guard let activeAccountProfileID else { return nil }
        return accountProfiles.first(where: { $0.id == activeAccountProfileID && $0.isEnabled })
    }

    private func activeAccountProfileForLaunch() -> PiAccountProfile? {
        activeAccountProfile
    }

    var connectedProviderIDs: Set<String> {
        var providers = Set(authEntries.map { normalizeProviderID($0.provider) })
        providers.formUnion(accountProfiles.filter { $0.isEnabled }.map { normalizeProviderID($0.provider) })
        providers.formUnion(configuredModelProviderIDs())

        let trimmedCLIProvider = cliProvider.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCLIProvider.isEmpty && !cliApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            providers.insert(normalizeProviderID(trimmedCLIProvider))
        }

        if let currentModel {
            providers.insert(normalizeProviderID(currentModel.provider))
        }

        return providers
    }

    var connectedAvailableModels: [AgentModel] {
        let connected = connectedProviderIDs
        guard !connected.isEmpty else { return [] }
        return availableModels.filter { isProvider($0.provider, connectedTo: connected) }
    }

    var visibleModels: [AgentModel] {
        let hidden = Set(hiddenModelKeys)
        return connectedAvailableModels.filter { model in
            !hidden.contains(model.modelKey) || model.modelKey == currentModel?.modelKey
        }
    }

    var hiddenModels: [AgentModel] {
        let hidden = Set(hiddenModelKeys)
        return connectedAvailableModels.filter { model in
            hidden.contains(model.modelKey) && model.modelKey != currentModel?.modelKey
        }
    }

    var visibleModelGroups: [ModelProviderGroup] {
        groupedModels(visibleModels)
    }

    var hiddenModelGroups: [ModelProviderGroup] {
        groupedModels(hiddenModels)
    }

    var disconnectedModelCount: Int {
        max(0, availableModels.count - connectedAvailableModels.count)
    }

    func setModel(_ model: AgentModel) async {
        try? await rpc.setModel(provider: model.provider, modelId: model.id)
        currentModel = model
        unhideModelIfNeeded(model, notify: false)
    }

    func hideModel(_ model: AgentModel) {
        guard model.modelKey != currentModel?.modelKey else {
            show(notification: AppNotification(message: "Current model cannot be hidden", type: .warning))
            return
        }
        if !hiddenModelKeys.contains(model.modelKey) {
            hiddenModelKeys.append(model.modelKey)
            hiddenModelKeys.sort()
            persistHiddenModels()
            show(notification: AppNotification(message: "Hidden from selector: \(model.name)", type: .success))
        }
    }

    func showModel(_ model: AgentModel) {
        unhideModelIfNeeded(model, notify: true)
    }

    func resetHiddenModels() {
        hiddenModelKeys.removeAll()
        persistHiddenModels()
        show(notification: AppNotification(message: "All connected models are visible", type: .success))
    }

    private func unhideModelIfNeeded(_ model: AgentModel, notify: Bool) {
        guard hiddenModelKeys.contains(model.modelKey) else { return }
        hiddenModelKeys.removeAll { $0 == model.modelKey }
        persistHiddenModels()
        if notify {
            show(notification: AppNotification(message: "Visible in selector: \(model.name)", type: .success))
        }
    }

    private func persistHiddenModels() {
        UserDefaults.standard.set(hiddenModelKeys, forKey: "pi.hiddenModelKeys")
    }

    private func groupedModels(_ models: [AgentModel]) -> [ModelProviderGroup] {
        let grouped = Dictionary(grouping: models) { $0.provider }
        return grouped.keys.sorted { lhs, rhs in
            lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }.map { provider in
            ModelProviderGroup(
                id: provider,
                provider: provider,
                models: (grouped[provider] ?? []).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
                isConnected: isProvider(provider, connectedTo: connectedProviderIDs)
            )
        }
    }

    private func configuredModelProviderIDs() -> Set<String> {
        guard let data = modelsJSONText.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let providers = root["providers"] as? [String: Any] else {
            return []
        }
        return Set(providers.keys.map { normalizeProviderID($0) })
    }

    private func isProvider(_ provider: String, connectedTo connected: Set<String>) -> Bool {
        let normalized = normalizeProviderID(provider)
        return connected.contains(normalized)
    }

    private func normalizeProviderID(_ provider: String) -> String {
        provider.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
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

    func autoUpdatePiRuntimeIfNeeded() async {
        let trimmedPiPath = piPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let usesBundledRuntime = trimmedPiPath.isEmpty || trimmedPiPath == "pi"
        guard piRuntimeAutoUpdatesEnabled,
              usesBundledRuntime,
              piRuntimeManager.bundledRuntime() != nil,
              piRuntimeManager.shouldRunAutomaticCheck() else { return }

        let completed = await updatePiRuntime(
            showUpToDateNotification: false,
            showInstalledNotification: false,
            reconnectIfInstalled: false
        )
        if completed { piRuntimeManager.markAutomaticCheck() }
    }

    @discardableResult
    func updatePiRuntime(
        showUpToDateNotification: Bool = true,
        showInstalledNotification: Bool = true,
        reconnectIfInstalled: Bool = true
    ) async -> Bool {
        guard !isCheckingPiRuntimeUpdates else { return false }
        isCheckingPiRuntimeUpdates = true
        defer { isCheckingPiRuntimeUpdates = false }

        do {
            let result = try await piRuntimeManager.installLatestIfNeeded()
            refreshPiRuntimeStatus()

            if result.installed {
                if reconnectIfInstalled, isConnected && !isStreaming {
                    if showInstalledNotification {
                        show(notification: AppNotification(message: "pi runtime \(result.version) installed. Reconnecting…", type: .success))
                    }
                    await reconnect()
                } else if showInstalledNotification {
                    show(notification: AppNotification(message: "pi runtime \(result.version) installed. It will be used on next reconnect.", type: .success))
                }
            } else if showUpToDateNotification {
                show(notification: AppNotification(message: result.message, type: .info))
            }
            return true
        } catch {
            if showUpToDateNotification {
                show(notification: AppNotification(message: "Failed to update pi runtime: \(error.localizedDescription)", type: .error))
            }
            return false
        }
    }

    func checkForPiChatUpdateIfNeeded() async {
        let defaults = UserDefaults.standard
        let last = defaults.object(forKey: automaticAppUpdateCheckKey) as? Date
        if let last, Date().timeIntervalSince(last) < 6 * 60 * 60 { return }
        await checkForPiChatUpdate(
            showNoUpdateNotification: false,
            respectDismissedVersion: true,
            recordAutomaticCheck: true
        )
    }

    @discardableResult
    func checkForPiChatUpdate(
        showNoUpdateNotification: Bool = true,
        respectDismissedVersion: Bool = false,
        recordAutomaticCheck: Bool = false
    ) async -> Bool {
        guard !isCheckingForUpdates else { return false }
        isCheckingForUpdates = true
        defer { isCheckingForUpdates = false }

        do {
            let release = try await fetchLatestGitHubRelease()
            if recordAutomaticCheck {
                UserDefaults.standard.set(Date(), forKey: automaticAppUpdateCheckKey)
            }

            let currentVersion = normalizedVersionString(appVersion)
            let latestVersion = normalizedVersionString(release.tagName)

            guard isVersion(latestVersion, greaterThan: currentVersion) else {
                availableAppUpdate = nil
                if showNoUpdateNotification {
                    show(notification: AppNotification(message: "You already have the latest version (\(currentVersion))", type: .info))
                }
                return false
            }

            if respectDismissedVersion,
               dismissedAppUpdateTagThisLaunch == release.tagName {
                return true
            }

            let download = release.assets?.first(where: { $0.name.lowercased().hasSuffix(".dmg") })?.browserDownloadURL
                ?? "https://github.com/Rrollan/PiChat/releases/latest/download/PiChat-macOS.dmg"
            guard URL(string: download) != nil, URL(string: release.htmlURL) != nil else {
                show(notification: AppNotification(message: "Failed to build update link", type: .error))
                return false
            }

            availableAppUpdate = AppUpdateInfo(
                version: latestVersion,
                tagName: release.tagName,
                downloadURL: download,
                releaseURL: release.htmlURL
            )
            return true
        } catch {
            if showNoUpdateNotification {
                show(notification: AppNotification(message: "Failed to check updates: \(error.localizedDescription)", type: .error))
            }
            return false
        }
    }

    func updateFromGitHub() async {
        _ = await checkForPiChatUpdate(showNoUpdateNotification: true, respectDismissedVersion: false)
    }

    func openAvailableAppUpdate() {
        guard let update = availableAppUpdate, let url = URL(string: update.downloadURL) else { return }
        NSWorkspace.shared.open(url)
        show(notification: AppNotification(message: "Downloading PiChat \(update.version)…", type: .success))
    }

    func dismissAvailableAppUpdate() {
        if let update = availableAppUpdate {
            dismissedAppUpdateTagThisLaunch = update.tagName
        }
        availableAppUpdate = nil
    }

    private var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0.0.0"
    }

    private var automaticAppUpdateCheckKey: String {
        "pichat.update.lastAutomaticCheck.\(appVersion)"
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

    var browserToolsExtensionPath: String {
        if let bundled = Bundle.main.url(forResource: "index", withExtension: "ts", subdirectory: "browser-tools") {
            return bundled.path
        }
        return NativeMessagingInstaller.installedBrowserToolsExtensionPath.path
    }

    func persistBrowserSettings() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "browser.toolsEnabled")
        defaults.set(browserExtensionId.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "browser.extensionId")
    }

    private func formatBrowserBridgeTime(_ value: Double?) -> String {
        guard let value, value > 0 else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let date = Date(timeIntervalSince1970: value)
        return "\(formatter.localizedString(for: date, relativeTo: Date())) (\(date.formatted(date: .abbreviated, time: .shortened)))"
    }

    func refreshBrowserBridgeStatus() {
        let id = browserExtensionId.trimmingCharacters(in: .whitespacesAndNewlines)
        let manifest = NativeMessagingInstaller.manifestSnapshot()
        let pairing = NativeMessagingInstaller.readPairingSnapshot()
        browserBridgeManifestPath = NativeMessagingInstaller.chromeManifestPath.path
        browserBridgeAllowedOrigin = manifest.allowedOrigins.first ?? (id.isEmpty ? "Not configured" : "Not installed")
        browserBridgeLastSeenText = formatBrowserBridgeTime(pairing?.lastSeenAt)

        if let pairing {
            let hashPreview = String((pairing.tokenHash ?? "").prefix(12))
            if !pairing.pairingRequired {
                browserBridgePairingStatusText = "Trusted origin mode"
            } else if pairing.paired {
                let client = [pairing.client?.extensionId, pairing.client?.version, pairing.client?.surface]
                    .compactMap { value in
                        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        return trimmed.isEmpty ? nil : trimmed
                    }
                    .joined(separator: " • ")
                browserBridgePairingStatusText = client.isEmpty ? "Paired" : "Paired with \(client)"
            } else if pairing.pairingRequired {
                browserBridgePairingStatusText = hashPreview.isEmpty ? "Pairing required" : "Pairing required · token hash \(hashPreview)…"
            } else {
                browserBridgePairingStatusText = "Pairing not required"
            }
        } else {
            browserBridgePairingStatusText = "Pairing token not installed yet"
        }

        browserToolsEnabled = true
        let toolsFileExists = FileManager.default.fileExists(atPath: browserToolsExtensionPath)
        browserToolsStatusText = toolsFileExists ? "Browser control is on" : "Browser tool file is missing"

        guard !id.isEmpty else {
            browserBridgeStatusText = manifest.exists ? "Native host installed · add Browspi ID to connect" : "Not configured"
            return
        }

        guard let normalizedId = try? NativeMessagingInstaller.normalizeExtensionId(id) else {
            browserBridgeStatusText = "Paste Browspi ID from the extension"
            return
        }

        let expectedOrigin = "chrome-extension://\(normalizedId)/"
        browserBridgeAllowedOrigin = manifest.allowedOrigins.first ?? expectedOrigin
        if NativeMessagingInstaller.isInstalled(extensionId: id) {
            let recentlySeen = (pairing?.lastSeenAt).map { Date().timeIntervalSince1970 - $0 < 120 } ?? false
            browserBridgeStatusText = recentlySeen ? "Connected" : "Installed — open Browspi and press Connect"
        } else if manifest.exists {
            browserBridgeStatusText = "Installed for another extension — press Connect again"
        } else {
            browserBridgeStatusText = "Not connected"
        }
    }

    func disconnectBrowserNativeBridge() {
        do {
            try NativeMessagingInstaller.uninstall()
            browserBridgeStatusText = "Disconnected"
            browserBridgeAllowedOrigin = "Not configured"
            browserBridgePairingStatusText = "Not paired"
            refreshBrowserBridgeStatus()
            show(notification: AppNotification(message: "Browser connection removed", type: .success))
        } catch {
            show(notification: AppNotification(message: "Failed to disconnect browser: \(error.localizedDescription)", type: .error))
        }
    }

    func installBrowserNativeBridge() async {
        isInstallingBrowserBridge = true
        defer { isInstallingBrowserBridge = false }
        do {
            persistBrowserSettings()
            let result = try NativeMessagingInstaller.install(extensionId: browserExtensionId, pairingToken: nil)
            browserBridgeManifestPath = result.manifestPath
            browserBridgeAllowedOrigin = result.allowedOrigin
            refreshBrowserBridgeStatus()
            show(notification: AppNotification(message: "Browser connected for \(result.allowedOrigin). Reload Browspi and press Connect.", type: .success))
        } catch {
            browserBridgeStatusText = error.localizedDescription
            show(notification: AppNotification(message: "Browser bridge install failed: \(error.localizedDescription)", type: .error))
        }
    }

    func copyBrowserPairingToken() {
        persistBrowserSettings()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(browserPairingToken, forType: .string)
        show(notification: AppNotification(message: "Browser pairing token copied", type: .success))
    }

    func regenerateBrowserPairingToken() {
        browserPairingToken = NativeMessagingInstaller.generatePairingToken()
        persistBrowserSettings()
        try? NativeMessagingInstaller.writePairingConfig(token: browserPairingToken)
        refreshBrowserBridgeStatus()
        show(notification: AppNotification(message: "New Browser pairing token generated. Reconnect Browspi.", type: .warning))
    }

    func openBrowspiConnectInstructions() {
        let id = browserExtensionId.trimmingCharacters(in: .whitespacesAndNewlines)
        show(notification: AppNotification(message: id.isEmpty ? "Open Browspi, copy its ID, paste it here, then press Connect Browser." : "Open Browspi and press Connect.", type: .info))
        openChromeExtensionsPage()
    }

    func openBrowspiChromeExtensionPage() {
        let id = (try? NativeMessagingInstaller.normalizeExtensionId(browserExtensionId)) ?? ""
        let urlString = id.isEmpty ? "chrome://extensions/" : "chrome://extensions/?id=\(id)"
        guard let extensionsURL = URL(string: urlString) else { return }
        openChromeURL(extensionsURL)
    }

    func openChromeExtensionsPage() {
        guard let extensionsURL = URL(string: "chrome://extensions/") else { return }
        openChromeURL(extensionsURL)
    }

    private func openChromeURL(_ extensionsURL: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        if let defaultBrowserURL = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://example.com")!) {
            NSWorkspace.shared.open([extensionsURL], withApplicationAt: defaultBrowserURL, configuration: configuration) { [weak self] _, error in
                if let error {
                    self?.notification = AppNotification(message: "Could not open chrome://extensions/ in default browser: \(error.localizedDescription)", type: .warning)
                }
            }
            return
        }

        NSWorkspace.shared.open(extensionsURL)
    }

    func persistRuntimeSettings() {
        let defaults = UserDefaults.standard
        defaults.set(piPath, forKey: "pi.runtime.path")
        defaults.set(startupDirectory, forKey: "pi.runtime.startupDirectory")
        defaults.set(piConfigDirectory, forKey: "pi.runtime.configDirectory")
        defaults.set(piRuntimeAutoUpdatesEnabled, forKey: "pi.runtime.autoUpdatesEnabled")
        if let activeAccountProfileID {
            defaults.set(activeAccountProfileID, forKey: "pi.account.activeProfileID")
        } else {
            defaults.removeObject(forKey: "pi.account.activeProfileID")
        }
        defaults.set(autoAccountFailoverEnabled, forKey: "pi.account.autoFailoverEnabled")

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
        if let activeProfile = activeAccountProfileForLaunch(),
           let apiKey = configManager.accountProfileSecret(id: activeProfile.id),
           !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            args += ["--provider", activeProfile.provider]
            args += ["--api-key", apiKey.trimmingCharacters(in: .whitespacesAndNewlines)]
        } else {
            if !cliProvider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                args += ["--provider", cliProvider.trimmingCharacters(in: .whitespacesAndNewlines)]
            }
            if !cliApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                args += ["--api-key", cliApiKey.trimmingCharacters(in: .whitespacesAndNewlines)]
            }
        }
        if !cliModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            args += ["--model", cliModel.trimmingCharacters(in: .whitespacesAndNewlines)]
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

        if browserToolsEnabled && !cliNoExtensions && FileManager.default.fileExists(atPath: browserToolsExtensionPath) {
            args += ["--extension", browserToolsExtensionPath]
        }

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
        mcpJSONText = configManager.readRawFile(named: "mcp.json", defaultContent: "{}")
        authEntries = configManager.loadAuthEntries()
        mcpServers = configManager.loadMCPServers()
        accountProfiles = configManager.loadAccountProfiles()
        if let activeAccountProfileID, !accountProfiles.contains(where: { $0.id == activeAccountProfileID }) {
            self.activeAccountProfileID = nil
            UserDefaults.standard.removeObject(forKey: "pi.account.activeProfileID")
        }

        applySettingsFormFromJSON()
    }

    func saveSettingsJSON() {
        do {
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
            try configManager.writeRawFile(named: "models.json", content: modelsJSONText)
            show(notification: AppNotification(message: "models.json saved", type: .success))
            Task { await reconnect() }
        } catch {
            show(notification: AppNotification(message: "models.json error: \(error.localizedDescription)", type: .error))
        }
    }

    func saveAuthJSON() {
        do {
            try configManager.writeRawFile(named: "auth.json", content: authJSONText)
            authEntries = configManager.loadAuthEntries()
            show(notification: AppNotification(message: "auth.json saved", type: .success))
            Task { await reconnect() }
        } catch {
            show(notification: AppNotification(message: "auth.json error: \(error.localizedDescription)", type: .error))
        }
    }

    func saveMCPJSON() {
        do {
            try configManager.writeRawFile(named: "mcp.json", content: mcpJSONText)
            mcpServers = configManager.loadMCPServers()
            show(notification: AppNotification(message: "mcp.json saved", type: .success))
            Task { await reconnect() }
        } catch {
            show(notification: AppNotification(message: "mcp.json error: \(error.localizedDescription)", type: .error))
        }
    }

    func loadAccountProfiles() {
        accountProfiles = configManager.loadAccountProfiles()
    }

    func saveAccountProfile(name: String, provider: String, apiKey: String) {
        do {
            let profile = try configManager.upsertAccountProfile(name: name, provider: provider, apiKey: apiKey)
            accountProfiles = configManager.loadAccountProfiles()
            if activeAccountProfileID == nil {
                activeAccountProfileID = profile.id
                persistRuntimeSettings()
            }
            show(notification: AppNotification(message: "Account profile added: \(profile.name)", type: .success))
            if isConnected { Task { await reconnect() } }
        } catch {
            show(notification: AppNotification(message: "Failed to save account profile: provider, name, and API key are required", type: .error))
        }
    }

    func setActiveAccountProfile(_ id: String?) {
        activeAccountProfileID = id
        skippedAccountProfileIDs.removeAll()
        persistRuntimeSettings()
        if isConnected { Task { await reconnect() } }
    }

    func setAccountProfileEnabled(_ profile: PiAccountProfile, enabled: Bool) {
        do {
            try configManager.setAccountProfileEnabled(id: profile.id, isEnabled: enabled)
            accountProfiles = configManager.loadAccountProfiles()
            if !enabled && activeAccountProfileID == profile.id {
                activeAccountProfileID = nil
                persistRuntimeSettings()
            }
        } catch {
            show(notification: AppNotification(message: "Failed to update account profile: \(error.localizedDescription)", type: .error))
        }
    }

    func removeAccountProfile(_ profile: PiAccountProfile) {
        do {
            try configManager.removeAccountProfile(id: profile.id)
            accountProfiles = configManager.loadAccountProfiles()
            if activeAccountProfileID == profile.id {
                activeAccountProfileID = nil
                persistRuntimeSettings()
            }
            show(notification: AppNotification(message: "Account profile removed: \(profile.name)", type: .success))
            if isConnected { Task { await reconnect() } }
        } catch {
            show(notification: AppNotification(message: "Failed to remove account profile: \(error.localizedDescription)", type: .error))
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
            if isConnected { Task { await reconnect() } }
        } catch {
            show(notification: AppNotification(message: "Failed to save account: \(error.localizedDescription)", type: .error))
        }
    }

    func removeAccount(provider: String) {
        do {
            try configManager.removeAuth(provider: provider)
            loadConfigFiles()
            show(notification: AppNotification(message: "Account removed: \(provider)", type: .success))
            if isConnected { Task { await reconnect() } }
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
            if isConnected { Task { await reconnect() } }
        } catch {
            show(notification: AppNotification(message: "Failed to add model: \(error.localizedDescription)", type: .error))
        }
    }

    func addPiResource(kind: PiResourceKind, value: String) {
        let item = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !item.isEmpty else {
            show(notification: AppNotification(message: "Enter a package, file, or directory", type: .warning))
            return
        }
        mutateSettingsArray(key: kind.settingsKey, item: item, removing: false)
    }

    func removePiResource(kind: PiResourceKind, value: String) {
        let item = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !item.isEmpty else { return }
        mutateSettingsArray(key: kind.settingsKey, item: item, removing: true)
    }

    private func mutateSettingsArray(key: String, item: String, removing: Bool) {
        do {
            var root = (try configManager.readJsonFile(named: "settings.json", defaultObject: [:])) as? [String: Any] ?? [:]
            let existing = root[key] as? [Any] ?? []
            let filtered = existing.filter { value in
                guard let string = value as? String else { return true }
                return string != item
            }
            root[key] = removing ? filtered : filtered + [item]
            settingsJSONText = configManager.prettyPrinted(root)
            try configManager.writeRawFile(named: "settings.json", content: settingsJSONText)
            loadConfigFiles()
            show(notification: AppNotification(message: removing ? "Removed from \(key): \(item)" : "Added to \(key): \(item)", type: .success))
            if isConnected { Task { await reconnect() } }
        } catch {
            show(notification: AppNotification(message: "Failed to update \(key): \(error.localizedDescription)", type: .error))
        }
    }

    private func refreshResourcesAfterAgentInstallIfNeeded(toolName: String, args: String, output: String, isError: Bool) {
        guard !isError else { return }
        let text = "\(toolName)\n\(args)\n\(output)".lowercased()
        let markers = ["settings.json", "mcp.json", "auth.json", "models.json", "/skills", "/extensions", "pi install", "pi config", "npm install"]
        guard markers.contains(where: { text.contains($0) }) else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.loadConfigFiles()
            Task {
                await self.refreshCommands()
                await self.refreshModels()
            }
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
        let normalizedURL = url.standardizedFileURL
        guard !attachedFiles.contains(where: { $0.url.standardizedFileURL == normalizedURL }) else { return }

        let mime = mimeType(for: normalizedURL)
        var att = FileAttachment(url: normalizedURL, name: normalizedURL.lastPathComponent, mimeType: mime)
        let hasAccess = normalizedURL.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { normalizedURL.stopAccessingSecurityScopedResource() }
        }
        if let data = try? Data(contentsOf: normalizedURL) {
            att = FileAttachment(url: normalizedURL, name: normalizedURL.lastPathComponent, mimeType: mime,
                                  base64Data: data.base64EncodedString())
        }
        attachedFiles.append(att)
    }

    func removeAttachment(id: UUID) {
        attachedFiles.removeAll { $0.id == id }
    }

    func addPastedContent(_ content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        pastedContents.append(PastedContent(content: trimmed))
    }

    func removePastedContent(id: UUID) {
        pastedContents.removeAll { $0.id == id }
    }

    private func mimeType(for url: URL) -> String {
        if let type = UTType(filenameExtension: url.pathExtension),
           let mime = type.preferredMIMEType {
            return mime
        }

        let ext = url.pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "heic": return "image/heic"
        case "pdf": return "application/pdf"
        default: return "application/octet-stream"
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

struct AppUpdateInfo: Identifiable, Equatable {
    var id: String { tagName }
    let version: String
    let tagName: String
    let downloadURL: String
    let releaseURL: String
}

enum PiResourceKind: String, CaseIterable, Identifiable {
    case packages
    case extensions
    case skills
    case prompts
    case themes

    var id: String { rawValue }
    var settingsKey: String { rawValue }

    var title: String {
        switch self {
        case .packages: return "Package"
        case .extensions: return "Extension"
        case .skills: return "Skill"
        case .prompts: return "Prompt"
        case .themes: return "Theme"
        }
    }

    var icon: String {
        switch self {
        case .packages: return "shippingbox"
        case .extensions: return "puzzlepiece.extension"
        case .skills: return "sparkles"
        case .prompts: return "text.badge.star"
        case .themes: return "paintpalette"
        }
    }

    var help: String {
        switch self {
        case .packages: return "npm/git pi packages from settings.json"
        case .extensions: return "local extension files or directories"
        case .skills: return "local skill files or directories"
        case .prompts: return "prompt template paths"
        case .themes: return "theme file or directory paths"
        }
    }
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
