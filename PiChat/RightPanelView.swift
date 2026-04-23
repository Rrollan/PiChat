import SwiftUI

// MARK: - Right Panel (Tools & Activity)

struct RightPanelView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(Array(["Activity", "Queue"].enumerated()), id: \.0) { i, tab in
                    TabButton(title: tab, icon: i == 0 ? "bolt.fill" : "list.number",
                              isSelected: selectedTab == i) {
                        withAnimation(.spring(response: 0.25)) { selectedTab = i }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(DS.Colors.surfaceElevated)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(DS.Colors.border), alignment: .bottom)

            // Content
            switch selectedTab {
            case 0: ActivityTabView()
            case 1: QueueTabView()
            default: EmptyView()
            }
        }
        .frame(width: 240)
        .background(DS.Colors.surface)
        .overlay(Rectangle().frame(width: 1).foregroundStyle(DS.Colors.border), alignment: .leading)
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(title)
                    .font(DS.body(11, weight: isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? DS.Colors.accent : (isHovered ? DS.Colors.textSecondary : DS.Colors.textTertiary))
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .frame(maxWidth: .infinity)
            .background(isSelected ? DS.Colors.accentDim : .clear)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Activity Tab

struct ActivityTabView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.sm) {
                // Status header
                HStack {
                    if state.isStreaming {
                        PulsingDot(color: DS.Colors.accent, size: 6)
                        Text("Agent Running")
                            .font(DS.mono(11, weight: .medium))
                            .foregroundStyle(DS.Colors.accent)
                    } else if state.isCompacting {
                        PulsingDot(color: DS.Colors.yellow, size: 6)
                        Text("Compacting")
                            .font(DS.mono(11, weight: .medium))
                            .foregroundStyle(DS.Colors.yellow)
                    } else {
                        Circle().fill(DS.Colors.green).frame(width: 6, height: 6)
                        Text("Idle")
                            .font(DS.mono(11, weight: .medium))
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.top, DS.Spacing.md)

                if state.isRetrying, let msg = state.retryMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 10))
                            .foregroundStyle(DS.Colors.yellow)
                        Text(msg)
                            .font(DS.body(10))
                            .foregroundStyle(DS.Colors.yellow)
                    }
                    .padding(DS.Spacing.sm)
                    .background(DS.Colors.yellow.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(DS.Colors.yellow.opacity(0.2), lineWidth: 0.5))
                    .padding(.horizontal, DS.Spacing.md)
                }

                // Active tools
                if !state.activeTools.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        SectionHeader(title: "Running", icon: "bolt")
                            .padding(.horizontal, DS.Spacing.md)

                        ForEach(state.activeTools) { tool in
                            ActiveToolRow(tool: tool)
                        }
                    }
                }

                // Recent from messages
                let recentTools = recentToolCalls()
                if !recentTools.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        SectionHeader(title: "Recent", icon: "clock")
                            .padding(.horizontal, DS.Spacing.md)

                        ForEach(recentTools) { tool in
                            RecentToolRow(tool: tool)
                        }
                    }
                }

                if state.activeTools.isEmpty && recentTools.isEmpty && !state.isStreaming {
                    VStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .font(.system(size: 24))
                            .foregroundStyle(DS.Colors.textTertiary)
                        Text("No activity yet")
                            .font(DS.body(12))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                }

                Spacer(minLength: DS.Spacing.lg)
            }
        }
    }

    private func recentToolCalls() -> [ToolCall] {
        let tools = state.messages.flatMap { $0.toolCalls }.filter { !$0.isRunning }
        return Array(tools.suffix(8))
    }
}

struct ActiveToolRow: View {
    let tool: ToolCall
    @State private var rotation = 0.0

    var body: some View {
        HStack(spacing: 8) {
            // Pulsing icon
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(DS.Colors.yellow.opacity(0.12))
                    .frame(width: 24, height: 24)
                Image(systemName: toolIcon(tool.name))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DS.Colors.yellow)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        if tool.isRunning {
                            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) { rotation = 360 }
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(tool.name)
                    .font(DS.mono(11, weight: .medium))
                    .foregroundStyle(DS.Colors.textPrimary)
                if !tool.output.isEmpty {
                    Text(tool.output.prefix(60).trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(DS.mono(9))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            TypingIndicator()
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.yellow.opacity(0.04))
    }
}

struct RecentToolRow: View {
    let tool: ToolCall
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill((tool.isError ? DS.Colors.red : DS.Colors.green).opacity(0.12))
                        .frame(width: 20, height: 20)
                    Image(systemName: tool.isError ? "xmark" : toolIcon(tool.name))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(tool.isError ? DS.Colors.red : DS.Colors.green)
                }

                Text(tool.name)
                    .font(DS.mono(10))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .lineLimit(1)

                Spacer()

                if !tool.output.isEmpty {
                    IconButton(icon: isExpanded ? "chevron.up" : "chevron.down", size: 9) {
                        withAnimation(.spring(response: 0.2)) { isExpanded.toggle() }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, 5)

            if isExpanded && !tool.output.isEmpty {
                Divider().background(DS.Colors.border.opacity(0.5)).padding(.horizontal, DS.Spacing.md)
                ScrollView {
                    Text(tool.output)
                        .font(DS.mono(9))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DS.Spacing.sm)
                }
                .frame(maxHeight: 120)
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
    }
}

private func toolIcon(_ name: String) -> String {
    switch name.lowercased() {
    case "bash":                    return "terminal"
    case "read":                    return "doc.text"
    case "write":                   return "square.and.pencil"
    case "edit":                    return "pencil"
    case "grep", "find":            return "magnifyingglass"
    case let n where n.contains("web"):  return "globe"
    case let n where n.contains("git"):  return "arrow.triangle.branch"
    default:                        return "wrench"
    }
}

// MARK: - Queue Tab

struct QueueTabView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                // Steering queue
                if !state.steeringQueue.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        SectionHeader(title: "Steering", icon: "arrow.turn.up.right",
                                      trailing: AnyView(Badge(text: "\(state.steeringQueue.count)", color: DS.Colors.yellow)))
                        ForEach(Array(state.steeringQueue.enumerated()), id: \.0) { idx, msg in
                            QueueItemRow(index: idx + 1, text: msg, color: DS.Colors.yellow, icon: "arrow.turn.up.right")
                        }
                    }
                }

                // Follow-up queue
                if !state.followUpQueue.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        SectionHeader(title: "Follow-up", icon: "forward.end",
                                      trailing: AnyView(Badge(text: "\(state.followUpQueue.count)", color: DS.Colors.purple)))
                        ForEach(Array(state.followUpQueue.enumerated()), id: \.0) { idx, msg in
                            QueueItemRow(index: idx + 1, text: msg, color: DS.Colors.purple, icon: "forward.end")
                        }
                    }
                }

                if state.steeringQueue.isEmpty && state.followUpQueue.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 24))
                            .foregroundStyle(DS.Colors.textTertiary)
                        Text("Queue is empty")
                            .font(DS.body(12))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                }
            }
            .padding(DS.Spacing.md)
        }
    }
}

struct QueueItemRow: View {
    let index: Int
    let text: String
    let color: Color
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Text("\(index)")
                .font(DS.mono(9, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 14)

            Text(text)
                .font(DS.body(11))
                .foregroundStyle(DS.Colors.textSecondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DS.Spacing.sm)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(color.opacity(0.2), lineWidth: 0.5))
    }
}
