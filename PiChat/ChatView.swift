import SwiftUI

// MARK: - Chat View

struct ChatView: View {
    @EnvironmentObject var state: AppState
    @Namespace private var bottomAnchor

    var body: some View {
        VStack(spacing: 0) {
            // Chat Header
            ChatHeaderView()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if state.messages.isEmpty && !state.isStreaming {
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
                    .padding(.vertical, DS.Spacing.lg)
                }
                .onChange(of: state.messages.count) {
                    withAnimation { proxy.scrollTo("bottom") }
                }
                .onChange(of: state.messages.last?.text) {
                    proxy.scrollTo("bottom")
                }
            }

            // Input Area
            InputAreaView()
        }
        .background(DS.Colors.background)
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
        .background(DS.Colors.surface)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(DS.Colors.border), alignment: .bottom)
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
        VStack(spacing: DS.Spacing.xxxl) {
            Spacer(minLength: 60)

            // Logo
            VStack(spacing: DS.Spacing.xs) {
                ThemedLogo()
                    .frame(width: 240, height: 240)
                    .opacity(0.9)
                    .padding(.bottom, -45)

                VStack(spacing: 8) {
                    Text("PiChat")
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                        .foregroundStyle(DS.Colors.textPrimary)
                    Text("Powered by \(state.currentModel?.name ?? "pi agent")")
                        .font(DS.mono(12))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            }

            // Suggestion grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.sm) {
                ForEach(suggestions, id: \.1) { icon, title, desc in
                    SuggestionCard(icon: icon, title: title, description: desc)
                }
            }
            .frame(maxWidth: 480)

            Spacer(minLength: 40)
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
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DS.Colors.accent)
                Text(title)
                    .font(DS.body(13, weight: .semibold))
                    .foregroundStyle(DS.Colors.textPrimary)
                Text(description)
                    .font(DS.body(11))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.md)
            .background(isHovered ? DS.Colors.accentDim : DS.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(isHovered ? DS.Colors.accent.opacity(0.4) : DS.Colors.border, lineWidth: 1)
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

struct AssistantMessageView: View {
    let message: ChatMessage
    @State private var showThinking = false

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            // Avatar
            AssistantReplyAvatar()
                .frame(width: 28, height: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {

                // Thinking block
                if !message.thinkingText.isEmpty {
                    ThinkingBlockView(text: message.thinkingText)
                }

                // Tool calls (inline)
                ForEach(message.toolCalls) { tool in
                    ToolCallCardView(tool: tool)
                }

                // Main text
                if !message.text.isEmpty {
                    if message.isStreaming && message.text.isEmpty {
                        TypingIndicator()
                            .padding(.vertical, 8)
                    } else {
                        MarkdownTextView(text: message.text, isStreaming: message.isStreaming)
                    }
                } else if message.isStreaming {
                    TypingIndicator().padding(.vertical, 8)
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
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(DS.Colors.textPrimary)
                .scaleEffect(scale)
                .shadow(color: DS.Colors.textSecondary.opacity(glow * 0.22), radius: 6)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: scale)
        }
        .onAppear {
            scale = 1.08
            glow = 0.9
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

                    Text(tool.name)
                        .font(DS.mono(11, weight: .medium))
                        .foregroundStyle(DS.Colors.textSecondary)

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

struct MarkdownTextView: View {
    let text: String
    let isStreaming: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(attributedText)
                .font(DS.body(14))
                .foregroundStyle(DS.Colors.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isStreaming {
                // Streaming cursor blink
                RoundedRectangle(cornerRadius: 1)
                    .fill(DS.Colors.accent)
                    .frame(width: 2, height: 14)
                    .opacity(1)
                    .animation(.easeInOut(duration: 0.5).repeatForever(), value: isStreaming)
            }
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
