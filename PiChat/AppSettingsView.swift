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
    @State private var accountProfileName = ""
    @State private var accountProfileKey = ""

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
    @State private var packageResource = ""
    @State private var extensionResource = ""
    @State private var skillResource = ""
    @State private var promptResource = ""
    @State private var themeResource = ""

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
            .frame(maxWidth: .infinity, alignment: .leading)
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    modelVisibilityCard
                    customModelsCard
                case .project:
                    agentActionsCard
                case .browser:
                    browserAssistantCard
                case .advanced:
                    rpcBehaviorCard
                    resourceLibraryCard
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
        settingsCard(title: "Pi Runtime", subtitle: "Bundled runtime, updates, and working directories") {
            TextField("Pi executable (use 'pi' for bundled/default, or /full/path/to/pi)", text: $state.piPath)
                .textFieldStyle(.roundedBorder)
            TextField("Startup project directory", text: $state.startupDirectory).textFieldStyle(.roundedBorder)
            TextField("Pi config directory (~/.pi/agent)", text: $state.piConfigDirectory).textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "shippingbox")
                        .foregroundStyle(DS.Colors.accent)
                    Text(state.piRuntimeStatusText)
                        .font(DS.body(11, weight: .medium))
                        .foregroundStyle(DS.Colors.textSecondary)
                    Spacer()
                }
                Text("When the path is 'pi', PiChat prefers its bundled/updated runtime and falls back to PATH only if no bundled runtime exists.")
                    .font(DS.body(10))
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            .padding(DS.Spacing.sm)
            .background(DS.Colors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(DS.Colors.border, lineWidth: 1))

            Toggle("Silently auto-update bundled pi runtime daily", isOn: Binding<Bool>(
                get: { state.piRuntimeAutoUpdatesEnabled },
                set: { newValue in
                    state.piRuntimeAutoUpdatesEnabled = newValue
                    state.persistRuntimeSettings()
                }
            ))

            HStack(spacing: DS.Spacing.sm) {
                Button("Save") {
                    state.persistRuntimeSettings()
                    state.refreshPiRuntimeStatus()
                }
                .buttonStyle(.bordered)

                Button("Use Bundled") {
                    state.piPath = "pi"
                    state.persistRuntimeSettings()
                    state.refreshPiRuntimeStatus()
                }
                .buttonStyle(.bordered)

                Button(state.isCheckingPiRuntimeUpdates ? "Updating pi…" : "Update pi Runtime") {
                    Task { await state.updatePiRuntime() }
                }
                .buttonStyle(.bordered)
                .disabled(state.isCheckingPiRuntimeUpdates)

                Button("Reconnect") { Task { await state.reconnect() } }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var modelCard: some View {
        settingsCard(title: "Model", subtitle: "Current model and thinking level") {
            Menu {
                if state.visibleModelGroups.isEmpty {
                    Text("No connected models")
                } else {
                    ForEach(state.visibleModelGroups) { group in
                        Section(group.provider) {
                            ForEach(group.models, id: \.modelKey) { model in
                                Button("\(model.name)") {
                                    Task { await state.setModel(model) }
                                }
                            }
                        }
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
                Text("Connected providers: \(state.connectedProviderIDs.count)")
                    .font(DS.body(11))
                    .foregroundStyle(DS.Colors.textSecondary)
                Spacer()
                if state.disconnectedModelCount > 0 {
                    Text("\(state.disconnectedModelCount) unavailable")
                        .font(DS.mono(10, weight: .medium))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
            }

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

            if state.oauthAuthURLString != nil || state.oauthVerificationCode != nil || state.oauthAuthInstructions != nil {
                OAuthInstructionCard()
                    .environmentObject(state)
            }

            if let prompt = state.oauthPromptMessage, state.isOAuthLoginRunning {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(prompt)
                        .font(DS.body(11))
                        .foregroundStyle(DS.Colors.textSecondary)

                    HStack(spacing: DS.Spacing.sm) {
                        TextField(state.oauthPromptPlaceholder ?? "Paste code or redirect URL", text: $state.oauthPromptInput)
                            .textFieldStyle(.roundedBorder)
                        Button(state.oauthPromptAllowsEmpty ? "Continue" : "Submit") {
                            state.submitOAuthPromptInput()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!state.oauthPromptAllowsEmpty && state.oauthPromptInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if state.oauthPromptAllowsEmpty {
                        Text("Leave empty and press Continue for the default value.")
                            .font(DS.body(10))
                            .foregroundStyle(DS.Colors.textTertiary)
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
        settingsCard(title: "Account Profiles", subtitle: "Multiple API-key accounts with automatic failover when quota or rate limits are hit") {
            Toggle("Automatically switch to the next enabled account on 429 / quota errors", isOn: Binding<Bool>(
                get: { state.autoAccountFailoverEnabled },
                set: { value in
                    state.autoAccountFailoverEnabled = value
                    state.persistRuntimeSettings()
                }
            ))

            HStack(spacing: DS.Spacing.sm) {
                Picker("Active", selection: Binding<String>(
                    get: { state.activeAccountProfileID ?? "" },
                    set: { state.setActiveAccountProfile($0.isEmpty ? nil : $0) }
                )) {
                    Text("Use native auth / CLI flags").tag("")
                    ForEach(state.accountProfiles) { profile in
                        Text("\(profile.name) · \(profile.provider)").tag(profile.id)
                    }
                }
                .frame(maxWidth: 360)

                if let active = state.activeAccountProfile {
                    Label("Active: \(active.name)", systemImage: "person.crop.circle.badge.checkmark")
                        .font(DS.body(11, weight: .semibold))
                        .foregroundStyle(DS.Colors.green)
                }
            }

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Add API-key account")
                    .font(DS.body(12, weight: .semibold))
                HStack(spacing: DS.Spacing.sm) {
                    TextField("Name (Work, Personal, Backup…)", text: $accountProfileName)
                        .textFieldStyle(.roundedBorder)
                    Picker("Provider", selection: $accountProvider) {
                        ForEach(accountProviders, id: \.self) { Text($0).tag($0) }
                    }
                    .frame(maxWidth: 220)
                    TextField("or custom provider id", text: $customAccountProvider)
                        .textFieldStyle(.roundedBorder)
                    SecureField("API key", text: $accountProfileKey)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        let provider = customAccountProvider.trimmingCharacters(in: .whitespacesAndNewlines)
                        state.saveAccountProfile(
                            name: accountProfileName,
                            provider: provider.isEmpty ? accountProvider : provider,
                            apiKey: accountProfileKey
                        )
                        accountProfileName = ""
                        accountProfileKey = ""
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(DS.Spacing.sm)
            .background(DS.Colors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(DS.Colors.border, lineWidth: 1))

            if state.accountProfiles.isEmpty {
                Text("No profiles yet. Add OpenAI/ChatGPT, Gemini, Anthropic or custom API-key accounts above.")
                    .font(DS.body(11))
                    .foregroundStyle(DS.Colors.textTertiary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 10)], spacing: 10) {
                    ForEach(state.accountProfiles) { profile in
                        accountProfileRow(profile)
                    }
                }
            }

            DisclosureGroup("Native auth.json accounts") {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
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
                        Text("No native auth.json accounts yet")
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
                .padding(.top, DS.Spacing.sm)
            }
        }
    }

    private func accountProfileRow(_ profile: PiAccountProfile) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(DS.body(12, weight: .semibold))
                        .foregroundStyle(DS.Colors.textPrimary)
                    Text(profile.provider)
                        .font(DS.mono(10))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                Spacer()
                if state.activeAccountProfileID == profile.id {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(DS.Colors.green)
                }
            }
            Text("Key: \(profile.keyPreview)")
                .font(DS.mono(10))
                .foregroundStyle(DS.Colors.textSecondary)
            HStack {
                Toggle("Enabled", isOn: Binding<Bool>(
                    get: { profile.isEnabled },
                    set: { state.setAccountProfileEnabled(profile, enabled: $0) }
                ))
                .toggleStyle(.checkbox)
                Spacer()
                Button("Use") { state.setActiveAccountProfile(profile.id) }
                    .buttonStyle(.bordered)
                    .disabled(!profile.isEnabled)
                Button("Delete") { state.removeAccountProfile(profile) }
                    .buttonStyle(.bordered)
            }
        }
        .padding(DS.Spacing.sm)
        .background(DS.Colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(DS.Colors.border, lineWidth: 1))
    }

    private var modelVisibilityCard: some View {
        settingsCard(title: "Model Picker", subtitle: "Only connected providers are shown in chat. Hide noisy models without editing JSON.") {
            HStack(spacing: DS.Spacing.sm) {
                Label("\(state.connectedAvailableModels.count) connected", systemImage: "checkmark.circle")
                    .font(DS.body(11, weight: .semibold))
                    .foregroundStyle(DS.Colors.textSecondary)
                if state.disconnectedModelCount > 0 {
                    Label("\(state.disconnectedModelCount) disconnected", systemImage: "eye.slash")
                        .font(DS.body(11, weight: .semibold))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                Spacer()
                Button("Show all hidden") { state.resetHiddenModels() }
                    .buttonStyle(.bordered)
                    .disabled(state.hiddenModels.isEmpty)
            }

            if state.visibleModelGroups.isEmpty {
                Text("No connected models yet. Authenticate a provider above and reconnect PiChat.")
                    .font(DS.body(11))
                    .foregroundStyle(DS.Colors.textTertiary)
            } else {
                ForEach(state.visibleModelGroups) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            ProviderDot(provider: group.provider)
                            Text(group.provider)
                                .font(DS.mono(11, weight: .semibold))
                                .foregroundStyle(DS.Colors.textSecondary)
                            Spacer()
                            Text("\(group.models.count) visible")
                                .font(DS.mono(10))
                                .foregroundStyle(DS.Colors.textTertiary)
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 8)], spacing: 8) {
                            ForEach(group.models, id: \.modelKey) { model in
                                SettingsModelChip(model: model, isSelected: model.modelKey == state.currentModel?.modelKey) {
                                    state.hideModel(model)
                                }
                            }
                        }
                    }
                    .padding(DS.Spacing.sm)
                    .background(DS.Colors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(DS.Colors.border, lineWidth: 1))
                }
            }

            if !state.hiddenModels.isEmpty {
                DisclosureGroup("Hidden models (\(state.hiddenModels.count))") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 8)], spacing: 8) {
                        ForEach(state.hiddenModels, id: \.modelKey) { model in
                            Button {
                                state.showModel(model)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(model.name).lineLimit(1)
                                        Text(model.provider).font(DS.mono(9)).foregroundStyle(DS.Colors.textTertiary).lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "eye")
                                }
                                .font(DS.body(10))
                                .foregroundStyle(DS.Colors.textSecondary)
                                .padding(8)
                                .background(DS.Colors.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 6)
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

    private var browserAssistantCard: some View {
        settingsCard(title: "Browser Control", subtitle: "Connect Browspi to PiChat") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Status")
                        .font(DS.body(11, weight: .semibold))
                        .foregroundStyle(DS.Colors.textSecondary)
                    Spacer()
                    Text(state.browserBridgeStatusText)
                        .font(DS.body(11, weight: .bold))
                        .foregroundStyle(state.browserBridgeStatusText == "Connected" ? DS.Colors.green : DS.Colors.textPrimary)
                }
                HStack {
                    Text("Browser tools")
                        .font(DS.body(11, weight: .semibold))
                        .foregroundStyle(DS.Colors.textSecondary)
                    Spacer()
                    Text(state.browserToolsStatusText)
                        .font(DS.body(11, weight: .bold))
                        .foregroundStyle(DS.Colors.green)
                }
                HStack {
                    Text("Last seen")
                        .font(DS.body(11, weight: .semibold))
                        .foregroundStyle(DS.Colors.textSecondary)
                    Spacer()
                    Text(state.browserBridgeLastSeenText)
                        .font(DS.body(11))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .textSelection(.enabled)
                }
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, 8)
            .background(DS.Colors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(DS.Colors.border, lineWidth: 1))

            VStack(alignment: .leading, spacing: 6) {
                Text("Browspi ID")
                    .font(DS.body(11, weight: .semibold))
                    .foregroundStyle(DS.Colors.textSecondary)
                TextField("Paste Browspi ID", text: $state.browserExtensionId)
                    .font(DS.mono(12))
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: state.browserExtensionId) { _, _ in
                        state.persistBrowserSettings()
                        state.refreshBrowserBridgeStatus()
                    }
            }

            HStack(spacing: DS.Spacing.sm) {
                Button("Connect Browser") {
                    Task { await state.installBrowserNativeBridge() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(state.isInstallingBrowserBridge || state.browserExtensionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Disconnect") { state.disconnectBrowserNativeBridge() }
                    .buttonStyle(.bordered)

                Button("Open Chrome Extension") { state.openBrowspiChromeExtensionPage() }
                    .buttonStyle(.bordered)

                Button("Refresh") { state.refreshBrowserBridgeStatus() }
                    .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("How to connect")
                    .font(DS.body(11, weight: .semibold))
                    .foregroundStyle(DS.Colors.textPrimary)
                Text("1. Open Browspi extension in Chrome.\n2. If it is not connected, copy the Browspi ID shown in the red card.\n3. Paste the ID here and press Connect Browser.\n4. Reload Browspi in Chrome and press Connect there. Browser control is enabled by default.")
                    .font(DS.body(11))
                    .foregroundStyle(DS.Colors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, 8)
            .background(DS.Colors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(DS.Colors.border, lineWidth: 1))
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

    private var resourceLibraryCard: some View {
        settingsCard(title: "Pi Resources", subtitle: "Install packages, skills, extensions, prompts, and themes from one place") {
            Text("These entries are saved to settings.json. You can also ask the agent in chat to install a skill or MCP server; PiChat will refresh this panel after the agent changes settings.json or mcp.json.")
                .font(DS.body(11))
                .foregroundStyle(DS.Colors.textTertiary)

            resourceRow(kind: .packages, text: $packageResource, currentCSV: state.sPackages, placeholder: "pi-skills or github:user/repo")
            resourceRow(kind: .skills, text: $skillResource, currentCSV: state.sSkills, placeholder: "~/.pi/agent/skills/my-skill")
            resourceRow(kind: .extensions, text: $extensionResource, currentCSV: state.sExtensions, placeholder: "~/.pi/agent/extensions/tool.ts")
            resourceRow(kind: .prompts, text: $promptResource, currentCSV: state.sPrompts, placeholder: "~/.pi/agent/prompts")
            resourceRow(kind: .themes, text: $themeResource, currentCSV: state.sThemes, placeholder: "~/.pi/agent/themes")

            Divider()

            HStack(spacing: DS.Spacing.sm) {
                Label("MCP servers", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(DS.body(11, weight: .semibold))
                Spacer()
                Badge(text: "\(state.mcpServers.count)", color: DS.Colors.green)
            }
            Text("Edit mcp.json in the raw JSON editor below. Servers appear in the right panel after reconnect.")
                .font(DS.body(10))
                .foregroundStyle(DS.Colors.textTertiary)
        }
    }

    private func resourceRow(kind: PiResourceKind, text: Binding<String>, currentCSV: String, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: kind.icon)
                    .foregroundStyle(DS.Colors.accent)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(kind.title)
                        .font(DS.body(11, weight: .semibold))
                    Text(kind.help)
                        .font(DS.body(9))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                Spacer()
            }

            HStack(spacing: DS.Spacing.sm) {
                TextField(placeholder, text: text)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    state.addPiResource(kind: kind, value: text.wrappedValue)
                    text.wrappedValue = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            let items = currentCSV.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            if !items.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(items, id: \.self) { item in
                        HStack(spacing: 5) {
                            Text(item)
                                .font(DS.mono(9))
                                .lineLimit(1)
                            Button {
                                state.removePiResource(kind: kind, value: item)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(DS.Colors.surfaceElevated)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(DS.Colors.border, lineWidth: 0.5))
                    }
                }
            }
        }
        .padding(DS.Spacing.sm)
        .background(DS.Colors.background.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(DS.Colors.border.opacity(0.8), lineWidth: 1))
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
                    jsonEditor(title: "mcp.json", text: $state.mcpJSONText, saveAction: state.saveMCPJSON)
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

private struct SettingsModelChip: View {
    let model: AgentModel
    let isSelected: Bool
    let onHide: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(model.name)
                    .font(DS.body(10, weight: isSelected ? .semibold : .regular))
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
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DS.Colors.accent)
            } else {
                Button(action: onHide) {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Hide from chat selector")
            }
        }
        .padding(8)
        .background(isSelected ? DS.Colors.accentDim : DS.Colors.background.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(isSelected ? DS.Colors.borderAccent : DS.Colors.border.opacity(0.7), lineWidth: 1))
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 640
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private struct OAuthInstructionCard: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                Image(systemName: "key.viewfinder")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DS.Colors.green)
                    .frame(width: 30, height: 30)
                    .background(DS.Colors.green.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Verification step")
                        .font(DS.body(12, weight: .semibold))
                        .foregroundStyle(DS.Colors.textPrimary)
                    Text("PiChat opened the provider page. Use the code below if the browser asks for it.")
                        .font(DS.body(10))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                Spacer()
                if state.oauthAuthURLString != nil {
                    Button("Open again") { state.openOAuthAuthURL() }
                        .buttonStyle(.bordered)
                }
            }

            if let code = state.oauthVerificationCode {
                HStack(spacing: DS.Spacing.sm) {
                    Text(code)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .tracking(1.8)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .textSelection(.enabled)
                    Spacer()
                    Button("Copy code") { state.copyOAuthVerificationCode() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(DS.Spacing.sm)
                .background(DS.Colors.background.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(DS.Colors.green.opacity(0.35), lineWidth: 1))
            }

            if let instructions = state.oauthAuthInstructions, !instructions.isEmpty {
                Text(instructions)
                    .font(DS.body(10, weight: .medium))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .textSelection(.enabled)
            }
        }
        .padding(DS.Spacing.md)
        .background(
            LinearGradient(
                colors: [DS.Colors.green.opacity(0.10), DS.Colors.surfaceElevated],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.green.opacity(0.25), lineWidth: 1))
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
    case browser
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .accounts: return "Accounts & Models"
        case .project: return "Project"
        case .browser: return "Browser"
        case .advanced: return "Advanced"
        }
    }

    var subtitle: String {
        switch self {
        case .general: return "Theme, runtime, current model"
        case .accounts: return "Authentication and custom providers"
        case .project: return "Folder, session, actions"
        case .browser: return "Browspi native bridge"
        case .advanced: return "CLI, JSON, low-level controls"
        }
    }

    var icon: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .accounts: return "person.crop.rectangle.stack"
        case .project: return "folder"
        case .browser: return "globe"
        case .advanced: return "wrench.and.screwdriver"
        }
    }
}
