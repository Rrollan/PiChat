import SwiftUI
import UniformTypeIdentifiers

// MARK: - Chat View

struct ChatView: View {
    @EnvironmentObject var state: AppState
    @Namespace private var bottomAnchor
    @State private var isAttachmentDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            // Chat Header
            ChatHeaderView()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if state.messages.isEmpty && !state.isStreaming && !state.isWaitingForResponse {
                            WelcomeView()
                        } else {
                            ForEach(state.messages) { msg in
                                MessageView(message: msg)
                            }
                        }

                        // Retry / Compaction status
                        if state.isRetrying {
                            RetryBannerView(message: state.retryMessage ?? "Retrying…")
                        }
                        if state.isCompacting {
                            CompactingBannerView()
                        }

                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .frame(maxWidth: 860)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.xl)
                }
                .onChange(of: state.messages.count) {
                    withAnimation { proxy.scrollTo("bottom") }
                }
                .onChange(of: state.messages.last?.text) {
                    proxy.scrollTo("bottom")
                }
                .onChange(of: state.isWaitingForResponse) {
                    proxy.scrollTo("bottom")
                }
            }

            // Input Area
            InputAreaView()
        }
        .background(DS.Colors.background)
        .onDrop(of: AttachmentIngress.acceptedAttachmentTypes, isTargeted: $isAttachmentDropTargeted) { providers in
            handleAttachmentDrop(providers)
            return true
        }
        .overlay {
            if isAttachmentDropTargeted {
                ChatAttachmentDropOverlay()
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .allowsHitTesting(false)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isAttachmentDropTargeted)
    }

    private func handleAttachmentDrop(_ providers: [NSItemProvider]) {
        AttachmentIngress.loadAttachmentURLs(from: providers) { urls in
            guard !urls.isEmpty else {
                state.show(notification: AppNotification(message: "No supported files found", type: .warning))
                return
            }
            for url in urls { state.addFile(url: url) }
            state.show(notification: AppNotification(message: "Dropped files: \(urls.count)", type: .success))
        }
    }
}

struct ChatAttachmentDropOverlay: View {
    var body: some View {
        ZStack {
            DS.Colors.background.opacity(0.58)
                .background(.ultraThinMaterial)

            VStack(spacing: DS.Spacing.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.xl)
                        .fill(DS.Colors.accentDim)
                        .frame(width: 92, height: 92)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.xl)
                                .stroke(DS.Colors.borderAccent, lineWidth: 1)
                        )

                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(DS.Colors.textPrimary)
                }

                VStack(spacing: 6) {
                    Text("Drop files into chat")
                        .font(DS.display(24, weight: .semibold))
                        .foregroundStyle(DS.Colors.textPrimary)
                    Text("Images become visual attachments. Other files are added as cards below.")
                        .font(DS.body(13))
                        .foregroundStyle(DS.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: DS.Spacing.sm) {
                    DropHintPill(icon: "photo", text: "PNG / JPG / GIF")
                    DropHintPill(icon: "doc", text: "Files")
                    DropHintPill(icon: "doc.on.clipboard", text: "Finder copy")
                }
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 30)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(DS.Colors.surfaceElevated.opacity(0.94))
                    .shadow(color: .black.opacity(0.22), radius: 34, x: 0, y: 22)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [9, 7]))
                    .foregroundStyle(DS.Colors.borderAccent)
            )
            .padding(42)
        }
    }
}

private struct DropHintPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(DS.mono(10, weight: .semibold))
        }
        .foregroundStyle(DS.Colors.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(DS.Colors.background.opacity(0.72))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(DS.Colors.border, lineWidth: 1))
    }
}

// MARK: - Chat Header

struct ChatHeaderView: View {
    @EnvironmentObject var state: AppState
    @State private var isFolderButtonHovered = false

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(state.sessionName ?? "New Session")
                    .font(DS.display(14, weight: .semibold))
                    .foregroundStyle(DS.Colors.textPrimary)
                if let sf = state.sessionFile {
                    Text(URL(fileURLWithPath: sf).lastPathComponent)
                        .font(DS.mono(10))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
            }

            Spacer()

            // Queue indicators
            if !state.steeringQueue.isEmpty {
                Badge(text: "↺ \(state.steeringQueue.count)", color: DS.Colors.yellow)
            }
            if !state.followUpQueue.isEmpty {
                Badge(text: "⏭ \(state.followUpQueue.count)", color: DS.Colors.purple)
            }

            // Folder Switcher
            Button {
                selectNewFolder()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                    Text(URL(fileURLWithPath: state.rpc.workingDirectory).lastPathComponent)
                        .font(DS.body(11, weight: .semibold))
                }
                .foregroundStyle(isFolderButtonHovered ? DS.Colors.textPrimary : DS.Colors.textSecondary)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, 6)
                .background(isFolderButtonHovered ? DS.Colors.accentDim : DS.Colors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .stroke(isFolderButtonHovered ? DS.Colors.borderAccent : DS.Colors.border, lineWidth: 1)
                )
                .scaleEffect(isFolderButtonHovered ? 1.015 : 1)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { isFolderButtonHovered = $0 }
            .animation(.easeInOut(duration: 0.12), value: isFolderButtonHovered)
            .help(state.rpc.workingDirectory)

            // Abort button when streaming
            if state.isStreaming {
                Button {
                    Task { await state.abortCurrentOperation() }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "stop.fill")
                        Text("Stop")
                    }
                    .font(DS.body(12, weight: .medium))
                    .foregroundStyle(DS.Colors.red)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(DS.Colors.red.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(DS.Colors.red.opacity(0.3), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.md)
        .background(DS.Colors.background.opacity(0.94))
        .overlay(Rectangle().frame(height: 1).foregroundStyle(DS.Colors.border.opacity(0.75)), alignment: .bottom)
    }

    private func selectNewFolder() {
        guard let url = ScriptFilePicker.pickFolder(prompt: "Select Project Folder") else {
            state.show(notification: AppNotification(message: "Folder selection cancelled", type: .warning))
            return
        }

        let hasAccess = url.startAccessingSecurityScopedResource()
        Task {
            await state.changeProject(newDirectory: url.path)
            state.show(notification: AppNotification(message: "Project: \(url.lastPathComponent)", type: .success))
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
    }
}

// MARK: - Welcome View

struct WelcomeView: View {
    @EnvironmentObject var state: AppState

    let suggestions = [
        ("magnifyingglass", "Explore codebase", "Analyze the project structure"),
        ("wrench.and.screwdriver", "Fix a bug", "Debug and resolve issues"),
        ("sparkles", "Create feature", "Build something new"),
        ("doc.text", "Review code", "Check for improvements")
    ]

    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer(minLength: 44)

            VStack(spacing: 8) {
                ThemedLogo()
                    .frame(width: 210, height: 210)
                    .opacity(0.92)
                    .padding(.bottom, -40)

                Text("PiChat")
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .foregroundStyle(DS.Colors.textPrimary)

                Text("Powered by \(state.currentModel?.name ?? "pi agent")")
                    .font(DS.mono(12))
                    .foregroundStyle(DS.Colors.textSecondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.sm) {
                ForEach(suggestions, id: \.1) { icon, title, desc in
                    SuggestionCard(icon: icon, title: title, description: desc)
                }
            }
            .frame(maxWidth: 560)

            Spacer(minLength: 44)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SuggestionCard: View {
    let icon: String
    let title: String
    let description: String
    @EnvironmentObject var state: AppState
    @State private var isHovered = false

    var body: some View {
        Button {
            state.inputText = description
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(DS.Colors.accent)
                Text(title)
                    .font(DS.body(13, weight: .semibold))
                    .foregroundStyle(DS.Colors.textPrimary)
                Text(description)
                    .font(DS.body(11))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .padding(DS.Spacing.md)
            .background(isHovered ? DS.Colors.surfaceElevated : DS.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(isHovered ? DS.Colors.borderAccent : DS.Colors.border, lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.01 : 1)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.spring(response: 0.2), value: isHovered)
    }
}

// MARK: - Message View (Router)

struct MessageView: View {
    let message: ChatMessage

    var body: some View {
        Group {
            switch message.role {
            case .user:       UserMessageView(message: message)
            case .assistant:  AssistantMessageView(message: message)
            case .system:     SystemMessageView(message: message)
            case .tool:       EmptyView()
            }
        }
    }
}

// MARK: - User Message

struct UserMessageView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            Spacer(minLength: 60)

            VStack(alignment: .trailing, spacing: DS.Spacing.sm) {
                // Attachments
                if !message.attachments.isEmpty {
                    HStack(spacing: DS.Spacing.xs) {
                        ForEach(message.attachments) { att in
                            AttachmentChip(attachment: att, removable: false)
                        }
                    }
                }

                // Message bubble
                Text(message.text)
                    .font(DS.body(14))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .textSelection(.enabled)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.md)
                    .background(DS.Gradients.userBubble)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.lg)
                            .stroke(DS.Colors.borderAccent, lineWidth: 0.5)
                    )

                // Timestamp
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(DS.mono(9))
                    .foregroundStyle(DS.Colors.textTertiary)
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.xs)
    }
}

// MARK: - Assistant Message

struct WaitingAssistantMessageView: View {
    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            AssistantReplyAvatar()
                .frame(width: 42, height: 42)
                .padding(.top, -2)

            PiThinkingIndicator(thinkingText: "")
                .padding(.vertical, 6)

            Spacer(minLength: 60)
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.xs)
    }
}

struct AssistantMessageView: View {
    let message: ChatMessage
    @State private var showThinking = false

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            // Avatar
            AssistantReplyAvatar()
                .frame(width: 42, height: 42)
                .padding(.top, 0)

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {

                // Thinking UX:
                // - while streaming: always show the animated thinking header immediately;
                //   real reasoning appears inside as soon as the provider sends thinking_delta.
                // - after completion: show a collapsed disclosure with the real reasoning.
                if message.isStreaming {
                    PiThinkingIndicator(thinkingText: message.thinkingText)
                        .padding(.vertical, 8)
                } else if !message.thinkingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    CompletedThinkingBlock(text: message.thinkingText)
                }

                // Tool calls (inline)
                ForEach(message.toolCalls) { tool in
                    ToolCallCardView(tool: tool)
                }

                // Main text
                if !message.text.isEmpty {
                    MarkdownTextView(text: message.text, isStreaming: message.isStreaming)
                }

                // Timestamp
                if !message.isStreaming {
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(DS.mono(9))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
            }

            Spacer(minLength: 60)
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.xs)
    }
}

struct AssistantReplyAvatar: View {
    @State private var scale: CGFloat = 1.0
    @State private var glow: Double = 0.55

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(DS.Colors.surfaceElevated.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(DS.Colors.borderAccent.opacity(0.24), lineWidth: 0.6)
                )
                .frame(width: 32, height: 32)
            PiChatLogo(style: .mark314)
                .scaleEffect(1.55)
                .frame(width: 32, height: 32)
                .clipped()
        }
            .scaleEffect(scale)
            .shadow(color: DS.Colors.textSecondary.opacity(glow * 0.18), radius: 5)
            .animation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true), value: scale)
            .onAppear {
                scale = 1.03
                glow = 0.8
            }
            .onDisappear {
                scale = 1.0
                glow = 0.55
            }
    }
}

// MARK: - Thinking Block

struct ThinkingBlockView: View {
    let text: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.spring(response: 0.3)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "brain")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DS.Colors.purple)
                    Text("Thinking")
                        .font(DS.mono(10, weight: .medium))
                        .foregroundStyle(DS.Colors.purple)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(text)
                    .font(DS.body(11))
                    .foregroundStyle(DS.Colors.textTertiary)
                    .textSelection(.enabled)
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
        .padding(DS.Spacing.sm)
        .background(DS.Colors.purpleDim)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(DS.Colors.purple.opacity(0.2), lineWidth: 0.5))
    }
}

// MARK: - Tool Call Card

struct ToolCallCardView: View {
    let tool: ToolCall
    @State private var isExpanded = false
    @State private var rotation = 0.0

    var statusColor: Color {
        if tool.isRunning { return DS.Colors.yellow }
        if tool.isError { return DS.Colors.red }
        return DS.Colors.green
    }
    var statusIcon: String {
        if tool.isRunning { return "arrow.2.circlepath" }
        if tool.isError { return "xmark.circle" }
        return "checkmark.circle"
    }

    private var resourceInstallLabel: String? {
        let text = "\(tool.name) \(tool.args) \(tool.output)".lowercased()
        if text.contains("mcp.json") || text.contains("mcp server") { return "MCP configuration" }
        if text.contains("skill") || text.contains("/skills") { return "Skill install" }
        if text.contains("extension") || text.contains("/extensions") { return "Extension install" }
        if text.contains("pi install") || text.contains("npm install") || text.contains("settings.json") { return "Pi resource change" }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button {
                withAnimation(.spring(response: 0.25)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(statusColor.opacity(0.12))
                            .frame(width: 20, height: 20)
                        Image(systemName: statusIcon)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(statusColor)
                            .rotationEffect(.degrees(rotation))
                            .onChange(of: tool.isRunning) {
                                if tool.isRunning {
                                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) { rotation = 360 }
                                } else {
                                    withAnimation { rotation = 0 }
                                }
                            }
                            .onAppear {
                                if tool.isRunning {
                                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) { rotation = 360 }
                                }
                            }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(tool.name)
                            .font(DS.mono(11, weight: .medium))
                            .foregroundStyle(DS.Colors.textSecondary)
                        if let resourceInstallLabel {
                            Label(resourceInstallLabel, systemImage: "shippingbox.and.arrow.backward")
                                .font(DS.body(9, weight: .semibold))
                                .foregroundStyle(DS.Colors.green)
                        }
                    }

                    if tool.isRunning {
                        TypingIndicator()
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded && !tool.output.isEmpty {
                Divider().background(DS.Colors.border.opacity(0.5))

                ScrollView {
                    Text(tool.output)
                        .font(DS.mono(10))
                        .foregroundStyle(tool.isError ? DS.Colors.red : DS.Colors.textSecondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DS.Spacing.sm)
                }
                .frame(maxHeight: 200)
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
        .background(DS.Colors.toolBubble)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .stroke(statusColor.opacity(0.25), lineWidth: 0.5)
        )
        .animatedBorder(active: tool.isRunning)
    }
}

// MARK: - Markdown Text (simplified)

struct PiThinkingIndicator: View {
    let thinkingText: String
    @State private var phase = false
    @State private var elapsed = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                MiniSpinner()
                Text("Pi is thinking")
                    .font(DS.body(14, weight: .medium))
                    .foregroundStyle(shimmerStyle)
                    .animation(.linear(duration: 5.0).repeatForever(autoreverses: false), value: phase)
                Text("\(elapsed)s")
                    .font(DS.mono(11))
                    .foregroundStyle(DS.Colors.textTertiary)
            }


        }
        .onAppear { phase = true }
        .onReceive(timer) { _ in elapsed += 1 }
        .accessibilityLabel("Pi is thinking")
    }

    private var shimmerStyle: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: DS.Colors.textTertiary.opacity(0.48), location: 0.0),
                .init(color: DS.Colors.textSecondary.opacity(0.75), location: 0.35),
                .init(color: DS.Colors.textPrimary, location: 0.50),
                .init(color: DS.Colors.textSecondary.opacity(0.75), location: 0.65),
                .init(color: DS.Colors.textTertiary.opacity(0.48), location: 1.0)
            ],
            startPoint: UnitPoint(x: phase ? -1.4 : 1.8, y: 0.5),
            endPoint: UnitPoint(x: phase ? -0.1 : 3.1, y: 0.5)
        )
    }
}

struct MiniSpinner: View {
    @State private var rotation = 0.0

    var body: some View {
        Circle()
            .trim(from: 0.18, to: 0.86)
            .stroke(DS.Colors.textSecondary.opacity(0.78), style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
            .frame(width: 14, height: 14)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

struct ThinkingPreviewCard: View {
    let thinkingText: String
    @State private var offset: CGFloat = 0

    private var preview: String {
        thinkingText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            Text(preview)
                .font(DS.body(11))
                .foregroundStyle(DS.Colors.textSecondary)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(y: offset)
                .padding(DS.Spacing.md)

            VStack {
                LinearGradient(colors: [DS.Colors.surface.opacity(0.95), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 34)
                Spacer()
                LinearGradient(colors: [.clear, DS.Colors.surface.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 34)
            }
            .allowsHitTesting(false)
        }
        .frame(width: 360, height: 118)
        .background(DS.Colors.surface.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.border.opacity(0.7), lineWidth: 1))
        .clipped()
        .onAppear { startScroll() }
        .onChange(of: thinkingText) { _, _ in startScroll() }
    }

    private func startScroll() {
        offset = 34
        withAnimation(.linear(duration: 5.5).repeatForever(autoreverses: false)) {
            offset = -78
        }
    }
}

struct CompletedThinkingBlock: View {
    let text: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 13, weight: .medium))
                    Text("Thinking")
                        .font(DS.body(13, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .foregroundStyle(DS.Colors.textSecondary)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, 9)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(text)
                    .font(DS.body(12))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.bottom, DS.Spacing.md)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: 720, alignment: .leading)
        .background(DS.Colors.surface.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.border.opacity(0.75), lineWidth: 1))
    }
}

struct MarkdownTextView: View {
    let text: String
    let isStreaming: Bool
    @State private var shinePhase = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(attributedText)
                .font(DS.body(14))
                .foregroundStyle(textStyle)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onAppear { startShineIfNeeded() }
                .onChange(of: isStreaming) { _, _ in startShineIfNeeded() }

            if isStreaming {
                ShiningText(text: "responding", font: DS.mono(10, weight: .medium), duration: 1.8)
                    .padding(.top, 1)
            }
        }
    }

    private var textStyle: AnyShapeStyle {
        guard isStreaming else { return AnyShapeStyle(DS.Colors.textPrimary) }
        return AnyShapeStyle(
            LinearGradient(
                stops: [
                    .init(color: DS.Colors.textSecondary.opacity(0.72), location: 0.0),
                    .init(color: DS.Colors.textPrimary, location: 0.38),
                    .init(color: DS.Colors.textPrimary, location: 0.50),
                    .init(color: DS.Colors.textSecondary.opacity(0.72), location: 0.76),
                    .init(color: DS.Colors.textSecondary.opacity(0.72), location: 1.0)
                ],
                startPoint: UnitPoint(x: shinePhase ? -0.85 : 1.25, y: 0.5),
                endPoint: UnitPoint(x: shinePhase ? 0.25 : 2.35, y: 0.5)
            )
        )
    }

    private func startShineIfNeeded() {
        guard isStreaming else { return }
        shinePhase = false
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            shinePhase = true
        }
    }

    private var attributedText: AttributedString {
        (try? AttributedString(markdown: text,
                               options: AttributedString.MarkdownParsingOptions(
                                interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }
}

// MARK: - System Message

struct SystemMessageView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            Spacer()
            Text(message.text)
                .font(DS.mono(10))
                .foregroundStyle(DS.Colors.textTertiary)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
                .background(DS.Colors.border.opacity(0.4))
                .clipShape(Capsule())
            Spacer()
        }
        .padding(.vertical, DS.Spacing.xs)
        .padding(.horizontal, DS.Spacing.xl)
    }
}

// MARK: - Retry Banner

struct RetryBannerView: View {
    let message: String
    @State private var rotation = 0.0

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "arrow.2.circlepath")
                .font(.system(size: 11))
                .foregroundStyle(DS.Colors.yellow)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) { rotation = 360 }
                }
            Text(message)
                .font(DS.body(11))
                .foregroundStyle(DS.Colors.yellow)
        }
        .padding(.horizontal, DS.Spacing.md).padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.yellow.opacity(0.08))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(DS.Colors.yellow.opacity(0.2), lineWidth: 0.5))
        .padding(.vertical, DS.Spacing.xs)
    }
}

struct CompactingBannerView: View {
    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            TypingIndicator()
            Text("Compacting context…")
                .font(DS.body(11))
                .foregroundStyle(DS.Colors.accent)
        }
        .padding(.horizontal, DS.Spacing.md).padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.accentDim)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(DS.Colors.accent.opacity(0.2), lineWidth: 0.5))
        .padding(.vertical, DS.Spacing.xs)
    }
}

// MARK: - Attachment Chip

struct AttachmentChip: View {
    let attachment: FileAttachment
    var removable: Bool = true
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: attachment.isImage ? "photo" : "doc")
                .font(.system(size: 9))
                .foregroundStyle(DS.Colors.accent)
            Text(attachment.name)
                .font(DS.body(10))
                .foregroundStyle(DS.Colors.textSecondary)
                .lineLimit(1)
            if removable {
                Button { onRemove?() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(DS.Colors.surface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(DS.Colors.border, lineWidth: 0.5))
    }
}
