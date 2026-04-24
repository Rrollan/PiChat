import SwiftUI

struct AppSettingsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    @AppStorage("ui.themeMode") private var themeMode = "system"
    @AppStorage("ui.showSkillsSection") private var showSkillsSection = true
    @AppStorage("ui.showMCPSection") private var showMCPSection = true
    @AppStorage("ui.showRightPanel") private var showRightPanel = true

    @State private var customProvider = ""
    @State private var customModelId = ""

    @State private var accountProvider = "anthropic"
    @State private var customAccountProvider = ""
    @State private var accountKey = ""

    @State private var modelProvider = ""
    @State private var modelBaseUrl = ""
    @State private var modelApi = "openai-completions"
    @State private var modelApiKey = ""
    @State private var modelId = ""
    @State private var modelName = ""
    @State private var modelReasoning = false
    @State private var modelImages = false

    @State private var selectedSection: SettingsSection = .general
    @State private var showCLIFlags = false
    @State private var showFullSettingsForm = false
    @State private var showRawJSONEditors = false

    private let subscriptionProviders: [LoginProvider] = [
        .init(id: "anthropic", label: "Anthropic (Claude Pro/Max)"),
        .init(id: "github-copilot", label: "GitHub Copilot"),
        .init(id: "openai-codex", label: "OpenAI Codex"),
        .init(id: "google-antigravity", label: "Google Antigravity"),
        .init(id: "google-gemini-cli", label: "Google Gemini CLI")
    ]

    private let accountProviders = [
        "anthropic", "openai", "google", "azure-openai-responses", "mistral", "groq", "cerebras", "xai",
        "openrouter", "vercel-ai-gateway", "zai", "opencode", "opencode-go", "huggingface", "fireworks",
        "kimi-coding", "minimax", "minimax-cn", "github-copilot", "openai-codex", "google-antigravity", "google-gemini-cli"
    ]

    private let apiOptions = ["openai-completions", "openai-responses", "anthropic-messages", "google-generative-ai"]

    var body: some View {
        VStack(spacing: 0) {
            header

            HStack(spacing: 0) {
                sidebar
                Rectangle()
                    .fill(DS.Colors.border)
                    .frame(width: 1)
                content
            }
            .background(DS.Colors.background)
        }
        .frame(minWidth: 1020, minHeight: 720)
        .onAppear { state.loadConfigFiles() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("PiChat Settings")
                    .font(DS.display(18, weight: .semibold))
                    .foregroundStyle(DS.Colors.textPrimary)
                Text("Structured for fast setup and easy daily use")
                    .font(DS.body(11))
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(DS.Colors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
            .buttonStyle(.plain)
        }
        .padding(DS.Spacing.lg)
        .background(DS.Colors.surface)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(DS.Colors.border), alignment: .bottom)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            ForEach(SettingsSection.allCases) { section in
                sectionButton(section)
            }
            Spacer()
        }
        .padding(DS.Spacing.md)
        .frame(width: 250)
        .background(DS.Colors.surface)
    }

    private func sectionButton(_ section: SettingsSection) -> some View {
        Button {
            selectedSection = section
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: section.icon)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(section.title)
                        .font(DS.body(12, weight: .semibold))
                    Text(section.subtitle)
                        .font(DS.body(10))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .foregroundStyle(selectedSection == section ? DS.Colors.textPrimary : DS.Colors.textSecondary)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(selectedSection == section ? DS.Colors.surfaceElevated : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .stroke(selectedSection == section ? DS.Colors.border : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                switch selectedSection {
                case .general:
                    appearanceCard
                    interfaceCard
                    runtimeCard
                    modelCard
                case .accounts:
                    subscriptionAuthCard
                    accountCard
                    customModelsCard
                case .project:
                    agentActionsCard
                case .advanced:
                    rpcBehaviorCard
                    advancedDataCard
                }
            }
            .padding(DS.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var appearanceCard: some View {
        settingsCard(title: "Appearance", subtitle: "Basic interface look and feel") {
            Picker("Theme", selection: $themeMode) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.segmented)
        }
    }

    private var interfaceCard: some View {
        settingsCard(title: "Interface", subtitle: "Choose what is visible in side panels") {
            Toggle("Show Skills & Commands", isOn: $showSkillsSection)
            Toggle("Show MCP Servers", isOn: $showMCPSection)
            Toggle("Show Right Panel", isOn: $showRightPanel)
        }
    }

    private var runtimeCard: some View {
        settingsCard(title: "Pi Runtime", subtitle: "Binary path and working directories") {
            TextField("Pi executable (pi or /full/path/to/pi)", text: $state.piPath).textFieldStyle(.roundedBorder)
            TextField("Startup project directory", text: $state.startupDirectory).textFieldStyle(.roundedBorder)
            TextField("Pi config directory (~/.pi/agent)", text: $state.piConfigDirectory).textFieldStyle(.roundedBorder)

            HStack(spacing: DS.Spacing.sm) {
                Button("Save") { state.persistRuntimeSettings() }
                    .buttonStyle(.bordered)
                Button("Reconnect") { Task { await state.reconnect() } }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var modelCard: some View {
        settingsCard(title: "Model", subtitle: "Current model and thinking level") {
            Menu {
                ForEach(state.availableModels) { model in
                    Button("\(model.name) · \(model.provider)") {
                        Task { await state.setModel(model) }
                    }
                }
            } label: {
                HStack {
                    Text(state.currentModel.map { "\($0.name) · \($0.provider)" } ?? "Select model")
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down")
                }
                .font(DS.body(12))
                .foregroundStyle(DS.Colors.textPrimary)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(DS.Colors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(DS.Colors.border, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Picker("Thinking", selection: Binding<String>(
                get: { state.thinkingLevel },
                set: { newValue in Task { await state.setThinkingLevel(newValue) } }
            )) {
                Text("off").tag("off")
                Text("minimal").tag("minimal")
                Text("low").tag("low")
                Text("medium").tag("medium")
                Text("high").tag("high")
                Text("xhigh").tag("xhigh")
            }
            .pickerStyle(.segmented)

            Divider()

            HStack(spacing: DS.Spacing.sm) {
                TextField("Provider", text: $customProvider).textFieldStyle(.roundedBorder)
                TextField("Model ID", text: $customModelId).textFieldStyle(.roundedBorder)
                Button("Apply") { Task { await state.applyCustomModel(provider: customProvider, modelId: customModelId) } }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var subscriptionAuthCard: some View {
        settingsCard(title: "Subscription Authentication", subtitle: "Run Pi-native OAuth login flow") {
            Text("Opens provider auth link in browser and stores credentials in auth.json.")
                .font(DS.body(11))
                .foregroundStyle(DS.Colors.textTertiary)

            if let status = state.oauthLoginStatusText, !status.isEmpty {
                HStack(spacing: DS.Spacing.sm) {
                    if state.isOAuthLoginRunning {
                        ProgressView().controlSize(.small)
                    }
                    Text(status)
                        .font(DS.body(11, weight: .medium))
                        .foregroundStyle(DS.Colors.textPrimary)
                    Spacer()
                    if state.isOAuthLoginRunning {
                        Button("Cancel") { state.cancelOAuthLogin() }
                            .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, 8)
                .background(DS.Colors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(DS.Colors.border, lineWidth: 1))
            }

            if let prompt = state.oauthPromptMessage, state.isOAuthLoginRunning {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(prompt)
                        .font(DS.body(11))
                        .foregroundStyle(DS.Colors.textSecondary)

                    HStack(spacing: DS.Spacing.sm) {
                        TextField(state.oauthPromptPlaceholder ?? "Paste code or redirect URL", text: $state.oauthPromptInput)
                            .textFieldStyle(.roundedBorder)
                        Button("Submit") {
                            state.submitOAuthPromptInput()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(state.oauthPromptInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }

            ForEach(subscriptionProviders) { provider in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(provider.label)
                            .font(DS.body(12, weight: .semibold))
                        Text(provider.id)
                            .font(DS.mono(10))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    Spacer()
                    Button("Authenticate") {
                        Task { await state.startProviderLogin(provider.id) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(state.isOAuthLoginRunning)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var accountCard: some View {
        settingsCard(title: "Accounts (auth.json)", subtitle: "API key / env var / command-based auth") {
            HStack(spacing: DS.Spacing.sm) {
                Picker("Provider", selection: $accountProvider) {
                    ForEach(accountProviders, id: \.self) { Text($0).tag($0) }
                }
                .frame(maxWidth: 220)

                TextField("or custom provider id", text: $customAccountProvider)
                    .textFieldStyle(.roundedBorder)

                SecureField("API key / env var / !command", text: $accountKey)
                    .textFieldStyle(.roundedBorder)

                Button("Save") {
                    let provider = customAccountProvider.trimmingCharacters(in: .whitespacesAndNewlines)
                    state.upsertAccount(provider: provider.isEmpty ? accountProvider : provider, key: accountKey)
                    accountKey = ""
                }
                .buttonStyle(.borderedProminent)
            }

            if state.authEntries.isEmpty {
                Text("No saved accounts yet")
                    .font(DS.body(11))
                    .foregroundStyle(DS.Colors.textTertiary)
            } else {
                ForEach(state.authEntries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.provider).font(DS.mono(11, weight: .semibold))
                            Text("\(entry.type): \(entry.keyPreview)").font(DS.mono(10)).foregroundStyle(DS.Colors.textTertiary)
                        }
                        Spacer()
                        Button("Delete") { state.removeAccount(provider: entry.provider) }
                            .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var customModelsCard: some View {
        settingsCard(title: "Custom Provider / Model", subtitle: "Add your own provider in models.json") {
            TextField("Provider id", text: $modelProvider).textFieldStyle(.roundedBorder)
            TextField("Base URL", text: $modelBaseUrl).textFieldStyle(.roundedBorder)
            Picker("API", selection: $modelApi) { ForEach(apiOptions, id: \.self) { Text($0).tag($0) } }
            TextField("apiKey (literal / ENV_NAME / !command)", text: $modelApiKey).textFieldStyle(.roundedBorder)
            HStack {
                TextField("Model id", text: $modelId).textFieldStyle(.roundedBorder)
                TextField("Model name", text: $modelName).textFieldStyle(.roundedBorder)
            }
            Toggle("Reasoning model", isOn: $modelReasoning)
            Toggle("Supports image input", isOn: $modelImages)

            Button("Add model") {
                state.addCustomProviderModel(provider: modelProvider,
                                             baseUrl: modelBaseUrl,
                                             api: modelApi,
                                             apiKey: modelApiKey,
                                             modelId: modelId,
                                             modelName: modelName,
                                             reasoning: modelReasoning,
                                             supportsImages: modelImages)
                modelId = ""
                modelName = ""
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var agentActionsCard: some View {
        settingsCard(title: "Project & Session", subtitle: "Quick actions for the active agent") {
            HStack {
                Text("Current folder")
                    .foregroundStyle(DS.Colors.textSecondary)
                Spacer()
                Text(state.rpc.workingDirectory)
                    .font(DS.mono(10))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            HStack(spacing: DS.Spacing.sm) {
                Button("Change folder") {
                    if let url = ScriptFilePicker.pickFolder(prompt: "Select Project Folder") {
                        Task { await state.changeProject(newDirectory: url.path) }
                    }
                }
                .buttonStyle(.bordered)

                Button("New session") { Task { await state.startNewSession() } }
                    .buttonStyle(.bordered)

                Button("Compact") { Task { await state.compact() } }
                    .buttonStyle(.bordered)
            }
        }
    }

    private var rpcBehaviorCard: some View {
        settingsCard(title: "RPC Behavior", subtitle: "Queue handling and automatic recovery") {
            Picker("Steering mode", selection: Binding<String>(
                get: { state.steeringMode },
                set: { mode in Task { await state.setSteeringMode(mode) } }
            )) {
                Text("one-at-a-time").tag("one-at-a-time")
                Text("all").tag("all")
            }
            .pickerStyle(.segmented)

            Picker("Follow-up mode", selection: Binding<String>(
                get: { state.followUpMode },
                set: { mode in Task { await state.setFollowUpMode(mode) } }
            )) {
                Text("one-at-a-time").tag("one-at-a-time")
                Text("all").tag("all")
            }
            .pickerStyle(.segmented)

            Toggle("Auto compaction", isOn: Binding(
                get: { state.autoCompactionEnabled },
                set: { value in Task { await state.setAutoCompaction(value) } }
            ))
            Toggle("Auto retry", isOn: Binding(
                get: { state.autoRetryEnabled },
                set: { value in Task { await state.setAutoRetry(value) } }
            ))
        }
    }

    private var advancedDataCard: some View {
        settingsCard(title: "Advanced", subtitle: "For power users and troubleshooting") {
            DisclosureGroup("CLI launch flags", isExpanded: $showCLIFlags) {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Toggle("--no-session", isOn: $state.cliNoSession)
                    Toggle("--no-tools", isOn: $state.cliNoTools)
                    Toggle("--no-extensions", isOn: $state.cliNoExtensions)
                    Toggle("--no-skills", isOn: $state.cliNoSkills)
                    Toggle("--no-prompt-templates", isOn: $state.cliNoPromptTemplates)
                    Toggle("--no-themes", isOn: $state.cliNoThemes)
                    Toggle("--no-context-files", isOn: $state.cliNoContextFiles)
                    Toggle("--verbose", isOn: $state.cliVerbose)

                    TextField("--provider", text: $state.cliProvider).textFieldStyle(.roundedBorder)
                    TextField("--model", text: $state.cliModel).textFieldStyle(.roundedBorder)
                    TextField("--api-key", text: $state.cliApiKey).textFieldStyle(.roundedBorder)
                    TextField("--thinking", text: $state.cliThinking).textFieldStyle(.roundedBorder)
                    TextField("--models", text: $state.cliModels).textFieldStyle(.roundedBorder)
                    TextField("--session-dir", text: $state.cliSessionDir).textFieldStyle(.roundedBorder)
                    TextField("--session", text: $state.cliSession).textFieldStyle(.roundedBorder)
                    TextField("--fork", text: $state.cliFork).textFieldStyle(.roundedBorder)
                    TextField("--tools (comma-separated)", text: $state.cliTools).textFieldStyle(.roundedBorder)
                    TextField("--system-prompt", text: $state.cliSystemPrompt).textFieldStyle(.roundedBorder)
                    TextField("--append-system-prompt", text: $state.cliAppendSystemPrompt).textFieldStyle(.roundedBorder)
                    TextField("Extra args (space-separated)", text: $state.cliExtraArgs).textFieldStyle(.roundedBorder)

                    Button("Save CLI flags") { state.persistRuntimeSettings() }
                        .buttonStyle(.bordered)
                }
                .padding(.top, 6)
            }

            DisclosureGroup("settings.json (all fields)", isExpanded: $showFullSettingsForm) {
                fullSettingsForm
                    .padding(.top, 6)
            }

            DisclosureGroup("Raw JSON editor", isExpanded: $showRawJSONEditors) {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    jsonEditor(title: "settings.json", text: $state.settingsJSONText, saveAction: state.saveSettingsJSON)
                    jsonEditor(title: "models.json", text: $state.modelsJSONText, saveAction: state.saveModelsJSON)
                    jsonEditor(title: "auth.json", text: $state.authJSONText, saveAction: state.saveAuthJSON)
                    Button("Reload files") { state.loadConfigFiles() }
                        .buttonStyle(.bordered)
                }
                .padding(.top, 6)
            }
        }
    }

    private var fullSettingsForm: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Group {
                TextField("defaultProvider", text: $state.sDefaultProvider).textFieldStyle(.roundedBorder)
                TextField("defaultModel", text: $state.sDefaultModel).textFieldStyle(.roundedBorder)
                TextField("defaultThinkingLevel", text: $state.sDefaultThinkingLevel).textFieldStyle(.roundedBorder)
                Toggle("hideThinkingBlock", isOn: $state.sHideThinkingBlock)
                Toggle("quietStartup", isOn: $state.sQuietStartup)
                Toggle("collapseChangelog", isOn: $state.sCollapseChangelog)
                Toggle("enableInstallTelemetry", isOn: $state.sEnableInstallTelemetry)
                Toggle("showHardwareCursor", isOn: $state.sShowHardwareCursor)
                Toggle("enableSkillCommands", isOn: $state.sEnableSkillCommands)
            }

            HStack {
                TextField("theme", text: $state.sTheme).textFieldStyle(.roundedBorder)
                TextField("doubleEscapeAction", text: $state.sDoubleEscapeAction).textFieldStyle(.roundedBorder)
                TextField("treeFilterMode", text: $state.sTreeFilterMode).textFieldStyle(.roundedBorder)
            }
            HStack {
                TextField("editorPaddingX", text: $state.sEditorPaddingX).textFieldStyle(.roundedBorder)
                TextField("autocompleteMaxVisible", text: $state.sAutocompleteMaxVisible).textFieldStyle(.roundedBorder)
                TextField("transport", text: $state.sTransport).textFieldStyle(.roundedBorder)
            }
            HStack {
                TextField("thinkingBudgets.minimal", text: $state.sThinkingMinimal).textFieldStyle(.roundedBorder)
                TextField("low", text: $state.sThinkingLow).textFieldStyle(.roundedBorder)
                TextField("medium", text: $state.sThinkingMedium).textFieldStyle(.roundedBorder)
                TextField("high", text: $state.sThinkingHigh).textFieldStyle(.roundedBorder)
            }

            Toggle("compaction.enabled", isOn: $state.sCompactionEnabled)
            HStack {
                TextField("compaction.reserveTokens", text: $state.sCompactionReserveTokens).textFieldStyle(.roundedBorder)
                TextField("compaction.keepRecentTokens", text: $state.sCompactionKeepRecentTokens).textFieldStyle(.roundedBorder)
            }

            Toggle("branchSummary.skipPrompt", isOn: $state.sBranchSummarySkipPrompt)
            TextField("branchSummary.reserveTokens", text: $state.sBranchSummaryReserveTokens).textFieldStyle(.roundedBorder)

            Toggle("retry.enabled", isOn: $state.sRetryEnabled)
            HStack {
                TextField("retry.maxRetries", text: $state.sRetryMaxRetries).textFieldStyle(.roundedBorder)
                TextField("retry.baseDelayMs", text: $state.sRetryBaseDelayMs).textFieldStyle(.roundedBorder)
                TextField("retry.maxDelayMs", text: $state.sRetryMaxDelayMs).textFieldStyle(.roundedBorder)
            }

            HStack {
                TextField("steeringMode", text: $state.sSteeringMode).textFieldStyle(.roundedBorder)
                TextField("followUpMode", text: $state.sFollowUpMode).textFieldStyle(.roundedBorder)
            }

            Toggle("terminal.showImages", isOn: $state.sTerminalShowImages)
            Toggle("terminal.clearOnShrink", isOn: $state.sTerminalClearOnShrink)
            TextField("terminal.imageWidthCells", text: $state.sTerminalImageWidthCells).textFieldStyle(.roundedBorder)

            Toggle("images.autoResize", isOn: $state.sImagesAutoResize)
            Toggle("images.blockImages", isOn: $state.sImagesBlockImages)

            TextField("shellPath", text: $state.sShellPath).textFieldStyle(.roundedBorder)
            TextField("shellCommandPrefix", text: $state.sShellCommandPrefix).textFieldStyle(.roundedBorder)
            TextField("npmCommand (csv)", text: $state.sNpmCommand).textFieldStyle(.roundedBorder)
            TextField("sessionDir", text: $state.sSessionDir).textFieldStyle(.roundedBorder)
            TextField("enabledModels (csv)", text: $state.sEnabledModels).textFieldStyle(.roundedBorder)
            TextField("markdown.codeBlockIndent", text: $state.sMarkdownCodeBlockIndent).textFieldStyle(.roundedBorder)

            TextField("packages (csv)", text: $state.sPackages).textFieldStyle(.roundedBorder)
            TextField("extensions (csv)", text: $state.sExtensions).textFieldStyle(.roundedBorder)
            TextField("skills (csv)", text: $state.sSkills).textFieldStyle(.roundedBorder)
            TextField("prompts (csv)", text: $state.sPrompts).textFieldStyle(.roundedBorder)
            TextField("themes (csv)", text: $state.sThemes).textFieldStyle(.roundedBorder)

            HStack {
                Button("Apply form -> JSON") { state.applySettingsFormToJSON() }
                    .buttonStyle(.bordered)
                Button("Save form to settings.json") { state.saveSettingsFromForm() }
                    .buttonStyle(.borderedProminent)
                Button("Reload form from settings.json") { state.applySettingsFormFromJSON() }
                    .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private func settingsCard<Content: View>(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DS.body(13, weight: .semibold))
                    .foregroundStyle(DS.Colors.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(DS.body(11))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
            }

            VStack(alignment: .leading, spacing: DS.Spacing.sm) { content() }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.border, lineWidth: 1))
    }

    @ViewBuilder
    private func jsonEditor(title: String, text: Binding<String>, saveAction: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(DS.mono(11, weight: .semibold))
                Spacer()
                Button("Save", action: saveAction).buttonStyle(.bordered)
            }

            TextEditor(text: text)
                .font(DS.mono(11))
                .foregroundStyle(DS.Colors.textPrimary)
                .frame(minHeight: 130)
                .padding(6)
                .background(DS.Colors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(DS.Colors.border, lineWidth: 1))
        }
    }
}

private struct LoginProvider: Identifiable {
    let id: String
    let label: String
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case accounts
    case project
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .accounts: return "Accounts & Models"
        case .project: return "Project"
        case .advanced: return "Advanced"
        }
    }

    var subtitle: String {
        switch self {
        case .general: return "Theme, runtime, current model"
        case .accounts: return "Authentication and custom providers"
        case .project: return "Folder, session, actions"
        case .advanced: return "CLI, JSON, low-level controls"
        }
    }

    var icon: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .accounts: return "person.crop.rectangle.stack"
        case .project: return "folder"
        case .advanced: return "wrench.and.screwdriver"
        }
    }
}
