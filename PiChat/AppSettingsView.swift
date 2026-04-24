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
    @State private var accountKey = ""

    @State private var modelProvider = ""
    @State private var modelBaseUrl = ""
    @State private var modelApi = "openai-completions"
    @State private var modelApiKey = ""
    @State private var modelId = ""
    @State private var modelName = ""
    @State private var modelReasoning = false
    @State private var modelImages = false

    private let accountProviders = [
        "anthropic", "openai", "google", "azure-openai-responses", "mistral", "groq", "cerebras", "xai",
        "openrouter", "vercel-ai-gateway", "zai", "opencode", "opencode-go", "huggingface", "fireworks",
        "kimi-coding", "minimax", "minimax-cn"
    ]

    private let apiOptions = ["openai-completions", "openai-responses", "anthropic-messages", "google-generative-ai"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Pi Settings (Full)")
                    .font(DS.display(18, weight: .semibold))
                    .foregroundStyle(DS.Colors.textPrimary)
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

            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    appearanceCard
                    interfaceCard
                    runtimeCard
                    cliLaunchCard
                    modelCard
                    fullSettingsCard
                    rpcBehaviorCard
                    accountCard
                    customModelsCard
                    rawJsonCard
                    agentActionsCard
                }
                .padding(DS.Spacing.lg)
            }
            .background(DS.Colors.background)
        }
        .frame(minWidth: 980, minHeight: 700)
        .onAppear { state.loadConfigFiles() }
    }

    private var appearanceCard: some View {
        settingsCard(title: "Appearance") {
            Picker("Theme", selection: $themeMode) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.segmented)
        }
    }

    private var interfaceCard: some View {
        settingsCard(title: "PiChat Interface") {
            Toggle("Show Skills & Commands", isOn: $showSkillsSection)
            Toggle("Show MCP Servers", isOn: $showMCPSection)
            Toggle("Show Right Panel", isOn: $showRightPanel)
        }
    }

    private var runtimeCard: some View {
        settingsCard(title: "Pi Runtime") {
            TextField("Pi executable (pi or /full/path/to/pi)", text: $state.piPath).textFieldStyle(.roundedBorder)
            TextField("Startup directory", text: $state.startupDirectory).textFieldStyle(.roundedBorder)
            TextField("Pi config directory (~/.pi/agent)", text: $state.piConfigDirectory).textFieldStyle(.roundedBorder)

            HStack(spacing: DS.Spacing.sm) {
                Button("Save Runtime") { state.persistRuntimeSettings() }
                    .buttonStyle(.bordered)
                Button("Reconnect") { Task { await state.reconnect() } }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var cliLaunchCard: some View {
        settingsCard(title: "CLI Launch Flags (for --mode rpc)") {
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
    }

    private var modelCard: some View {
        settingsCard(title: "Current Model") {
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

            HStack(spacing: DS.Spacing.sm) {
                TextField("Provider", text: $customProvider).textFieldStyle(.roundedBorder)
                TextField("Model ID", text: $customModelId).textFieldStyle(.roundedBorder)
                Button("Apply") { Task { await state.applyCustomModel(provider: customProvider, modelId: customModelId) } }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var fullSettingsCard: some View {
        settingsCard(title: "settings.json — all documented fields") {
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

            HStack { TextField("theme", text: $state.sTheme).textFieldStyle(.roundedBorder)
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

    private var rpcBehaviorCard: some View {
        settingsCard(title: "RPC queue controls") {
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

    private var accountCard: some View {
        settingsCard(title: "Accounts (auth.json)") {
            HStack(spacing: DS.Spacing.sm) {
                Picker("Provider", selection: $accountProvider) {
                    ForEach(accountProviders, id: \.self) { Text($0).tag($0) }
                }
                SecureField("API key / env var / !command", text: $accountKey).textFieldStyle(.roundedBorder)
                Button("Save") {
                    state.upsertAccount(provider: accountProvider, key: accountKey)
                    accountKey = ""
                }
                .buttonStyle(.borderedProminent)
            }

            if state.authEntries.isEmpty {
                Text("Нет сохранённых аккаунтов").font(DS.body(11)).foregroundStyle(DS.Colors.textTertiary)
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
        settingsCard(title: "Add custom model (models.json)") {
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

    private var rawJsonCard: some View {
        settingsCard(title: "Raw Pi JSON") {
            jsonEditor(title: "settings.json", text: $state.settingsJSONText, saveAction: state.saveSettingsJSON)
            jsonEditor(title: "models.json", text: $state.modelsJSONText, saveAction: state.saveModelsJSON)
            jsonEditor(title: "auth.json", text: $state.authJSONText, saveAction: state.saveAuthJSON)
            Button("Reload files") { state.loadConfigFiles() }.buttonStyle(.bordered)
        }
    }

    private var agentActionsCard: some View {
        settingsCard(title: "Agent") {
            HStack {
                Text("Project").foregroundStyle(DS.Colors.textSecondary)
                Spacer()
                Text(state.rpc.workingDirectory).font(DS.mono(10)).lineLimit(1).truncationMode(.middle)
            }
            HStack(spacing: DS.Spacing.sm) {
                Button("Change Folder") {
                    if let url = ScriptFilePicker.pickFolder(prompt: "Select Project Folder") {
                        Task { await state.changeProject(newDirectory: url.path) }
                    }
                }
                .buttonStyle(.bordered)
                Button("New Session") { Task { await state.startNewSession() } }.buttonStyle(.bordered)
                Button("Compact") { Task { await state.compact() } }.buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(title)
                .font(DS.body(13, weight: .semibold))
                .foregroundStyle(DS.Colors.textPrimary)
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
