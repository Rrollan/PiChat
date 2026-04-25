import SwiftUI

// MARK: - Sidebar View

struct SidebarView: View {
    @EnvironmentObject var state: AppState
    @AppStorage("ui.showSkillsSection") private var showSkillsSection = true
    @AppStorage("ui.showMCPSection") private var showMCPSection = true

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

                    if showSkillsSection || showMCPSection {
                        Divider().background(DS.Colors.border)
                    }

                    // Skills
                    if showSkillsSection {
                        CommandsSectionView()
                    }

                    if showSkillsSection && showMCPSection {
                        Divider().background(DS.Colors.border)
                    }

                    // MCP
                    if showMCPSection {
                        MCPSectionView()
                    }
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
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
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    if state.visibleModels.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No connected models")
                                .font(DS.body(11, weight: .semibold))
                                .foregroundStyle(DS.Colors.textPrimary)
                            Text("Authenticate a provider in Settings → Accounts, then reconnect.")
                                .font(DS.body(10))
                                .foregroundStyle(DS.Colors.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(8)
                    } else {
                        ForEach(state.visibleModelGroups) { group in
                            ProviderGroupView(group: group) { model in
                                Task { await state.setModel(model) }
                                withAnimation { isExpanded = false }
                            } onHide: { model in
                                state.hideModel(model)
                            }
                        }
                    }

                    if !state.hiddenModels.isEmpty {
                        Divider().background(DS.Colors.border)
                        DisclosureGroup {
                            VStack(spacing: 2) {
                                ForEach(state.hiddenModels, id: \.modelKey) { model in
                                    HiddenModelRow(model: model) {
                                        state.showModel(model)
                                    }
                                }
                            }
                            .padding(.top, 4)
                        } label: {
                            Text("Hidden models (\(state.hiddenModels.count))")
                                .font(DS.mono(10, weight: .medium))
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                    }

                    if state.disconnectedModelCount > 0 {
                        Text("\(state.disconnectedModelCount) model\(state.disconnectedModelCount == 1 ? "" : "s") hidden because provider is not connected")
                            .font(DS.body(10))
                            .foregroundStyle(DS.Colors.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(6)
                .background(DS.Colors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.border, lineWidth: 1))
                .transition(.scale(scale: 0.95, anchor: .top).combined(with: .opacity))
            }
        }
    }
}

struct ProviderDot: View {
    let provider: String
    var color: Color { DS.Colors.accent }

    var body: some View {
        Circle()
            .fill(color.opacity(0.9))
            .frame(width: 7, height: 7)
            .overlay(Circle().stroke(DS.Colors.borderAccent, lineWidth: 0.5))
    }
}

struct ProviderGroupView: View {
    @EnvironmentObject var state: AppState
    let group: ModelProviderGroup
    let onSelect: (AgentModel) -> Void
    let onHide: (AgentModel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                ProviderDot(provider: group.provider)
                Text(group.provider)
                    .font(DS.mono(10, weight: .semibold))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .lineLimit(1)
                Spacer()
                Text("\(group.models.count)")
                    .font(DS.mono(9, weight: .medium))
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            .padding(.horizontal, 6)

            VStack(spacing: 2) {
                ForEach(group.models, id: \.modelKey) { model in
                    ModelRow(
                        model: model,
                        isSelected: model.modelKey == state.currentModel?.modelKey,
                        onSelect: { onSelect(model) },
                        onHide: { onHide(model) }
                    )
                }
            }
        }
    }
}

struct ModelRow: View {
    let model: AgentModel
    let isSelected: Bool
    let onSelect: () -> Void
    let onHide: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(model.name)
                    .font(DS.body(11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? DS.Colors.textPrimary : DS.Colors.textSecondary)
                    .lineLimit(1)
                Text(model.provider)
                    .font(DS.mono(9))
                    .foregroundStyle(DS.Colors.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DS.Colors.accent)
            } else if isHovered {
                Button(action: onHide) {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help("Hide model from selector")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? DS.Colors.accentDim : isHovered ? DS.Colors.border.opacity(0.45) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { isHovered = $0 }
    }
}

struct HiddenModelRow: View {
    let model: AgentModel
    let onShow: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(model.name)
                    .font(DS.body(10))
                    .foregroundStyle(DS.Colors.textTertiary)
                    .lineLimit(1)
                Text(model.provider)
                    .font(DS.mono(9))
                    .foregroundStyle(DS.Colors.textTertiary.opacity(0.8))
                    .lineLimit(1)
            }
            Spacer()
            Button(action: onShow) {
                Image(systemName: "eye")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help("Show model in selector")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(DS.Colors.background.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct ThinkingLevelPicker: View {
    @EnvironmentObject var state: AppState
    let levels = ["off", "low", "medium", "high"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(levels, id: \.self) { level in
                let isSelected = state.thinkingLevel == level
                Button {
                    Task { await state.setThinkingLevel(level) }
                } label: {
                    Text(level)
                        .font(DS.mono(9, weight: isSelected ? .bold : .regular))
                        .foregroundStyle(isSelected ? DS.Colors.accent : DS.Colors.textTertiary)
                        .padding(.horizontal, 6).padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                        .background(isSelected ? DS.Colors.accentDim : .clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 18)
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
        .contentShape(Rectangle())
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

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SectionHeader(title: "MCP Servers", icon: "network",
                          trailing: AnyView(Badge(text: "\(state.mcpServers.count)", color: DS.Colors.green)))

            if state.mcpServers.isEmpty {
                Text("No MCP servers configured")
                    .font(DS.body(11))
                    .foregroundStyle(DS.Colors.textTertiary)
            } else {
                VStack(spacing: 4) {
                    ForEach(state.mcpServers) { server in
                        MCPServerRow(name: server.name, description: server.description,
                                     icon: serverIcon(name: server.name), color: serverColor(name: server.name))
                    }
                }
            }
        }
    }

    private func serverIcon(name: String) -> String {
        let lowercase = name.lowercased()
        if lowercase.contains("github") || lowercase.contains("git") { return "arrow.triangle.branch" }
        if lowercase.contains("browser") || lowercase.contains("web") { return "globe" }
        if lowercase.contains("memory") || lowercase.contains("vector") { return "brain" }
        if lowercase.contains("design") || lowercase.contains("magic") { return "wand.and.stars" }
        return "server.rack"
    }

    private func serverColor(name: String) -> Color {
        let palette: [Color] = [DS.Colors.green, DS.Colors.purple, DS.Colors.accent, DS.Colors.yellow]
        let index = abs(name.hashValue) % palette.count
        return palette[index]
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
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
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
    @State private var showAppSettings = false

    var body: some View {
        HStack(spacing: 0) {
            IconButton(icon: "plus.square", color: DS.Colors.textSecondary, hoverColor: DS.Colors.accent) {
                Task { await state.startNewSession() }
            }
            .help("New Session")

            Spacer(minLength: 0)

            IconButton(icon: "arrow.clockwise", color: DS.Colors.textSecondary, hoverColor: DS.Colors.purple) {
                Task {
                    await state.refreshStats()
                    await state.refreshCommands()
                }
            }
            .help("Refresh")

            Spacer(minLength: 0)

            IconButton(icon: state.isCheckingForUpdates ? "hourglass" : "arrow.down.app", color: DS.Colors.textSecondary, hoverColor: DS.Colors.green) {
                Task { await state.updateFromGitHub() }
            }
            .disabled(state.isCheckingForUpdates)
            .help(state.isCheckingForUpdates ? "Checking updates..." : "Update PiChat")

            Spacer(minLength: 0)

            IconButton(icon: "gearshape", color: DS.Colors.textSecondary, hoverColor: DS.Colors.accent) {
                showAppSettings = true
            }
            .help("Settings")
            .sheet(isPresented: $showAppSettings) {
                AppSettingsView()
                    .environmentObject(state)
            }

            Spacer(minLength: 0)

            IconButton(icon: "archivebox", color: DS.Colors.textSecondary, hoverColor: DS.Colors.yellow) {
                Task { await state.compact() }
            }
            .disabled(state.isStreaming)
            .help("Compact")
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surfaceElevated)
        .overlay(
            Rectangle().frame(height: 1).foregroundStyle(DS.Colors.border),
            alignment: .top
        )
    }
}
