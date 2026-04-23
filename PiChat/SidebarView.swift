import SwiftUI

// MARK: - Sidebar View

struct SidebarView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Logo / Header
            SidebarHeaderView()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: DS.Spacing.lg) {
                    // Model Picker
                    ModelSectionView()

                    Divider().background(DS.Colors.border)

                    // Session Stats
                    StatsSectionView()

                    Divider().background(DS.Colors.border)

                    // Skills
                    CommandsSectionView()

                    Divider().background(DS.Colors.border)

                    // MCP
                    MCPSectionView()
                }
                .padding(DS.Spacing.lg)
            }

            // Bottom Actions
            SidebarActionsView()
        }
        .frame(width: 260)
        .background(DS.Colors.surface)
        .overlay(
            Rectangle().frame(width: 1).foregroundStyle(DS.Colors.border),
            alignment: .trailing
        )
    }
}

// MARK: - Sidebar Header

struct SidebarHeaderView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 10) {
            // Logo
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(DS.Gradients.accentLinear)
                    .frame(width: 28, height: 28)
                Text("π")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("PiChat")
                    .font(DS.display(14, weight: .bold))
                    .foregroundStyle(DS.Colors.textPrimary)
                HStack(spacing: 4) {
                    Circle()
                        .fill(state.isConnected ? DS.Colors.green : DS.Colors.textTertiary)
                        .frame(width: 5, height: 5)
                    Text(state.isConnected ? "Connected" : "Disconnected")
                        .font(DS.mono(10))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            }
            Spacer()
        }
        .padding(DS.Spacing.lg)
        .background(DS.Colors.surfaceElevated)
        .overlay(
            Rectangle().frame(height: 1).foregroundStyle(DS.Colors.border),
            alignment: .bottom
        )
    }
}

// MARK: - Model Section

struct ModelSectionView: View {
    @EnvironmentObject var state: AppState
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SectionHeader(title: "Model", icon: "cpu")
                .onTapGesture { withAnimation { isExpanded.toggle() } }

            // Current model
            if let model = state.currentModel {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        ProviderDot(provider: model.provider)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(model.name)
                                .font(DS.body(12, weight: .medium))
                                .foregroundStyle(DS.Colors.textPrimary)
                                .lineLimit(1)
                            Text(model.provider)
                                .font(DS.mono(10))
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                        Spacer()
                        IconButton(icon: isExpanded ? "chevron.up" : "chevron.down", size: 10) {
                            withAnimation(.spring(response: 0.3)) { isExpanded.toggle() }
                        }
                    }
                    .padding(DS.Spacing.sm)
                    .background(DS.Colors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(DS.Colors.border, lineWidth: 1))

                    // Thinking level
                    ThinkingLevelPicker()
                }
            }

            // Model list (expandable)
            if isExpanded {
                VStack(spacing: 2) {
                    ForEach(state.availableModels) { model in
                        ModelRow(model: model, isSelected: model.id == state.currentModel?.id)
                            .onTapGesture {
                                Task { await state.setModel(model) }
                                withAnimation { isExpanded = false }
                            }
                    }
                }
                .padding(6)
                .background(DS.Colors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(DS.Colors.border, lineWidth: 1))
                .transition(.scale(scale: 0.95, anchor: .top).combined(with: .opacity))
            }
        }
    }
}

struct ProviderDot: View {
    let provider: String
    var color: Color {
        switch provider.lowercased() {
        case let p where p.contains("anthropic"): return Color(hex: "#D97706")
        case let p where p.contains("google"), let p where p.contains("gemini"): return Color(hex: "#4285F4")
        case let p where p.contains("openai"): return Color(hex: "#10A37F")
        case let p where p.contains("github"): return Color(hex: "#8B5CF6")
        default: return DS.Colors.textSecondary
        }
    }

    var body: some View {
        Circle().fill(color).frame(width: 8, height: 8)
            .shadow(color: color.opacity(0.5), radius: 3)
    }
}

struct ModelRow: View {
    let model: AgentModel
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            ProviderDot(provider: model.provider)
            Text(model.name)
                .font(DS.body(11))
                .foregroundStyle(isSelected ? DS.Colors.accent : DS.Colors.textSecondary)
                .lineLimit(1)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DS.Colors.accent)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(isSelected ? DS.Colors.accentDim : isHovered ? DS.Colors.border.opacity(0.5) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .onHover { isHovered = $0 }
    }
}

struct ThinkingLevelPicker: View {
    @EnvironmentObject var state: AppState
    let levels = ["off", "low", "medium", "high"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(levels, id: \.self) { level in
                let isSelected = state.thinkingLevel == level
                Text(level)
                    .font(DS.mono(9, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? DS.Colors.accent : DS.Colors.textTertiary)
                    .padding(.horizontal, 6).padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background(isSelected ? DS.Colors.accentDim : .clear)
                    .onTapGesture {
                        Task { await state.setThinkingLevel(level) }
                    }
            }
        }
        .background(DS.Colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(DS.Colors.border, lineWidth: 1))
    }
}

// MARK: - Stats Section

struct StatsSectionView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SectionHeader(title: "Session", icon: "chart.bar.xaxis")

            ContextBar(percent: state.contextPercent, tokens: state.contextTokens, window: state.contextWindow)

            HStack(spacing: DS.Spacing.sm) {
                StatCell(label: "In", value: formatK(state.tokenInput), color: DS.Colors.green)
                StatCell(label: "Out", value: formatK(state.tokenOutput), color: DS.Colors.purple)
                StatCell(label: "Cost", value: "$\(String(format: "%.3f", state.sessionCost))", color: DS.Colors.yellow)
            }
        }
    }

    private func formatK(_ n: Int) -> String {
        n >= 1000 ? String(format: "%.1fk", Double(n) / 1000) : "\(n)"
    }
}

struct StatCell: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(DS.mono(11, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(DS.mono(9))
                .foregroundStyle(DS.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.sm)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(color.opacity(0.2), lineWidth: 0.5))
    }
}

// MARK: - Commands / Skills Section

struct CommandsSectionView: View {
    @EnvironmentObject var state: AppState
    @State private var showAll = false

    var visible: [AgentCommand] {
        showAll ? state.commands : Array(state.commands.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SectionHeader(title: "Skills & Commands", icon: "sparkles",
                          trailing: AnyView(Badge(text: "\(state.commands.count)", color: DS.Colors.purple)))

            if state.commands.isEmpty {
                Text("No commands loaded")
                    .font(DS.body(11))
                    .foregroundStyle(DS.Colors.textTertiary)
            } else {
                VStack(spacing: 2) {
                    ForEach(visible) { cmd in
                        CommandRow(cmd: cmd)
                    }
                    if state.commands.count > 5 {
                        Button {
                            withAnimation { showAll.toggle() }
                        } label: {
                            HStack {
                                Image(systemName: showAll ? "chevron.up" : "chevron.down")
                                Text(showAll ? "Show less" : "Show \(state.commands.count - 5) more")
                            }
                            .font(DS.body(10))
                            .foregroundStyle(DS.Colors.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }
                }
            }
        }
    }
}

struct CommandRow: View {
    let cmd: AgentCommand
    @EnvironmentObject var state: AppState
    @State private var isHovered = false

    var icon: String {
        switch cmd.source {
        case "skill": return "sparkle"
        case "prompt": return "doc.text"
        default: return "terminal"
        }
    }
    var color: Color {
        switch cmd.source {
        case "skill": return DS.Colors.purple
        case "prompt": return DS.Colors.green
        default: return DS.Colors.accent
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(color)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 0) {
                Text("/\(cmd.name)")
                    .font(DS.mono(10, weight: .medium))
                    .foregroundStyle(isHovered ? color : DS.Colors.textSecondary)
                if let desc = cmd.description, !desc.isEmpty {
                    Text(desc)
                        .font(DS.body(9))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 6).padding(.vertical, 4)
        .background(isHovered ? color.opacity(0.08) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .onHover { isHovered = $0 }
        .onTapGesture {
            state.inputText = "/\(cmd.name) "
        }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}

// MARK: - MCP Section

struct MCPSectionView: View {
    @EnvironmentObject var state: AppState

    // Static MCP info (from mcp.json we read earlier)
    let mcpServers: [(name: String, description: String, icon: String, color: Color)] = [
        ("21st-dev-magic", "Magic UI Components", "wand.and.stars", Color(hex: "#8B5CF6")),
        ("claude-flow", "Multi-agent orchestration", "arrow.triangle.branch", Color(hex: "#F59E0B"))
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SectionHeader(title: "MCP Servers", icon: "network",
                          trailing: AnyView(Badge(text: "\(mcpServers.count)", color: DS.Colors.green)))

            VStack(spacing: 4) {
                ForEach(mcpServers, id: \.name) { server in
                    MCPServerRow(name: server.name, description: server.description,
                                 icon: server.icon, color: server.color)
                }
            }
        }
    }
}

struct MCPServerRow: View {
    let name: String
    let description: String
    let icon: String
    let color: Color
    @State private var isExpanded = false
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(color.opacity(0.15))
                        .frame(width: 22, height: 22)
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(DS.body(11, weight: .medium))
                        .foregroundStyle(DS.Colors.textPrimary)
                        .lineLimit(1)
                    Text(description)
                        .font(DS.body(9))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .lineLimit(1)
                }
                Spacer()
                // Status dot
                PulsingDot(color: DS.Colors.green, size: 5)
            }
            .padding(8)
            .background(isHovered ? color.opacity(0.05) : .clear)
            .onHover { isHovered = $0 }
        }
        .background(DS.Colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(color.opacity(0.2), lineWidth: 0.5))
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}

// MARK: - Sidebar Actions

struct SidebarActionsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            IconButton(icon: "plus.square", label: "New", color: DS.Colors.textSecondary, hoverColor: DS.Colors.accent) {
                Task { await state.startNewSession() }
            }

            IconButton(icon: "arrow.clockwise", label: "Refresh", color: DS.Colors.textSecondary, hoverColor: DS.Colors.purple) {
                Task {
                    await state.refreshStats()
                    await state.refreshCommands()
                }
            }

            Spacer()

            IconButton(icon: "archivebox", label: "Compact", color: DS.Colors.textSecondary, hoverColor: DS.Colors.yellow) {
                Task { await state.compact() }
            }
            .disabled(state.isStreaming)
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surfaceElevated)
        .overlay(
            Rectangle().frame(height: 1).foregroundStyle(DS.Colors.border),
            alignment: .top
        )
    }
}
