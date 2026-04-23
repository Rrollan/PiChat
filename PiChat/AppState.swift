import Foundation
import Combine
import SwiftUI

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

    // MARK: Extension UI
    @Published var pendingUIRequest: ExtensionUIRequest?

    // MARK: Input
    @Published var inputText: String = ""
    @Published var attachedFiles: [FileAttachment] = []

    // MARK: Compaction
    @Published var isCompacting = false
    @Published var lastCompactionSummary: String?

    // MARK: Retry
    @Published var isRetrying = false
    @Published var retryMessage: String?

    let rpc = PiRPCClient()
    private var cancellables = Set<AnyCancellable>()
    private var currentAssistantMessageIndex: Int?
    private var activeToolCallMap: [String: Int] = [:] // toolCallId -> index in activeTools

    init() {
        setupEventHandling()
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

    func connect(piPath: String = "/opt/homebrew/bin/pi", workingDirectory: String = NSHomeDirectory()) async {
        isStarting = true
        connectionError = nil
        rpc.piPath = piPath
        rpc.workingDirectory = workingDirectory

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
        rpc.stop()
        isConnected = false
        messages.removeAll()
        activeTools.removeAll()
    }

    func changeProject(newDirectory: String) async {
        disconnect()
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
        availableModels = m ?? []
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
    }

    // MARK: - Event Handling

    private func handleEvent(_ event: AgentEvent) {
        switch event {

        case .agentStart:
            isWaitingForResponse = false
            isStreaming = true
            let msg = ChatMessage(role: .assistant, text: "", isStreaming: true)
            messages.append(msg)
            currentAssistantMessageIndex = messages.count - 1

        case .agentEnd:
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
            addSystemMessage("⚠️ Extension error: \(error)")

        case .response(_, let command, _, let error, let data):
            if command == "prompt" {
                isWaitingForResponse = false
            }
            if let e = error {
                show(notification: AppNotification(message: e, type: .error))
            }
            if command == "set_model" || command == "cycle_model" {
                if let m = data?.model { currentModel = m }
            }
            if command == "set_thinking_level" {
                // refresh state
                Task { if let s = try? await rpc.getState() { applyState(s) } }
            }

        default: break
        }
    }

    private func addSystemMessage(_ text: String) {
        messages.append(ChatMessage(role: .system, text: text))
    }

    // MARK: - Actions

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !attachedFiles.isEmpty else { return }

        var userMsg = ChatMessage(role: .user, text: text, attachments: attachedFiles)
        messages.append(userMsg)

        let images: [RPCImage] = attachedFiles.compactMap { att in
            guard att.isImage, let b64 = att.base64Data else { return nil }
            return RPCImage(data: b64, mimeType: att.mimeType)
        }

        inputText = ""
        attachedFiles = []
        isWaitingForResponse = true

        do {
            try await rpc.prompt(text, images: images)
        } catch {
            isWaitingForResponse = false
            addSystemMessage("❌ \(error.localizedDescription)")
        }
    }

    func abortCurrentOperation() async {
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
        try? await rpc.newSession()
        messages.removeAll()
        activeTools.removeAll()
        await loadInitialState()
    }

    func compact() async {
        try? await rpc.compact()
    }

    func setModel(_ model: AgentModel) async {
        try? await rpc.setModel(provider: model.provider, modelId: model.id)
        currentModel = model
    }

    func setThinkingLevel(_ level: String) async {
        try? await rpc.setThinkingLevel(level)
        thinkingLevel = level
    }

    func show(notification: AppNotification) {
        self.notification = notification
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if self.notification?.id == notification.id {
                self.notification = nil
            }
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
