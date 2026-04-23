import SwiftUI

// MARK: - Main Content View

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ZStack {
            if !state.isConnected && !state.isStarting {
                ConnectView()
            } else if state.isStarting {
                LoadingView()
            } else {
                MainLayout()
            }

            // Toast notifications
            if let notification = state.notification {
                VStack {
                    Spacer()
                    ToastView(notification: notification)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    Spacer().frame(height: DS.Spacing.xl)
                }
                .animation(.spring(response: 0.3), value: state.notification?.id)
            }

            // Extension UI dialogs
            ExtensionUIOverlay()
                .animation(.easeInOut(duration: 0.2), value: state.pendingUIRequest?.id)
        }
    }
}

// MARK: - Main 3-Column Layout

struct MainLayout: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
            ChatView()
            RightPanelView()
        }
        .background(DS.Colors.background)
        .frame(minWidth: 900, minHeight: 600)
        // Keyboard shortcuts
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willBecomeActiveNotification)) { _ in
            Task { await state.refreshStats() }
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    @State private var dots = 0
    @State private var scale = 1.0
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            DS.Gradients.backgroundRadial.ignoresSafeArea()

            VStack(spacing: DS.Spacing.xxxl) {
                // Pulsing logo
                ZStack {
                    Circle()
                        .fill(DS.Gradients.accentLinear)
                        .frame(width: 80, height: 80)
                        .blur(radius: 30)
                        .opacity(0.4)
                        .scaleEffect(scale)

                    Text("π")
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.Gradients.accentLinear)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever()) { scale = 1.3 }
                }

                VStack(spacing: DS.Spacing.sm) {
                    Text("Starting pi agent")
                        .font(DS.display(18, weight: .semibold))
                        .foregroundStyle(DS.Colors.textPrimary)

                    Text("Initializing RPC connection" + String(repeating: ".", count: dots))
                        .font(DS.mono(13))
                        .foregroundStyle(DS.Colors.textSecondary)
                        .animation(.none, value: dots)
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .onReceive(timer) { _ in dots = (dots + 1) % 4 }
    }
}

// MARK: - Connect View

struct ConnectView: View {
    @EnvironmentObject var state: AppState
    @State private var piPath = "/opt/homebrew/bin/pi"
    @State private var workDir = NSHomeDirectory()
    @State private var showSettings = false

    var body: some View {
        ZStack {
            // Background with gradient
            DS.Gradients.backgroundRadial.ignoresSafeArea()

            // Top glow
            DS.Gradients.glowTop.frame(height: 300).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea()

            VStack(spacing: DS.Spacing.xxxl) {
                Spacer()

                // Logo section
                VStack(spacing: DS.Spacing.xl) {
                    ZStack {
                        // Glow rings
                        ForEach([0, 1, 2], id: \.self) { i in
                            Circle()
                                .stroke(DS.Colors.accent.opacity(Double(3 - i) * 0.05), lineWidth: 1)
                                .frame(width: CGFloat(80 + i * 30), height: CGFloat(80 + i * 30))
                        }

                        // Main logo
                        ZStack {
                            Circle()
                                .fill(DS.Gradients.accentLinear)
                                .frame(width: 72, height: 72)
                                .shadow(color: DS.Colors.accent.opacity(0.4), radius: 20)
                            Text("π")
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                                .foregroundStyle(.black)
                        }
                    }

                    VStack(spacing: DS.Spacing.sm) {
                        Text("PiChat")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Colors.textPrimary)
                        Text("Native interface for pi coding agent")
                            .font(DS.mono(14))
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                }

                // Error
                if let err = state.connectionError {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(DS.Colors.red)
                        Text(err)
                            .font(DS.body(12))
                            .foregroundStyle(DS.Colors.red)
                    }
                    .padding(DS.Spacing.md)
                    .background(DS.Colors.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.red.opacity(0.3), lineWidth: 1))
                }

                // Settings toggle
                VStack(spacing: DS.Spacing.md) {
                    if showSettings {
                        VStack(spacing: DS.Spacing.sm) {
                            SettingsField(label: "pi path", value: $piPath, placeholder: "/opt/homebrew/bin/pi")
                            SettingsField(label: "Working dir", value: $workDir, placeholder: NSHomeDirectory())
                        }
                        .padding(DS.Spacing.lg)
                        .glassCard(radius: DS.Radius.lg, border: DS.Colors.border)
                        .frame(width: 380)
                        .transition(.scale(scale: 0.95, anchor: .top).combined(with: .opacity))
                    }

                    HStack(spacing: DS.Spacing.md) {
                        // Settings toggle
                        Button {
                            withAnimation(.spring(response: 0.3)) { showSettings.toggle() }
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 14))
                                .foregroundStyle(DS.Colors.textTertiary)
                                .frame(width: 40, height: 40)
                                .background(DS.Colors.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                                .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        // Connect button
                        Button {
                            Task { await state.connect(piPath: piPath, workingDirectory: workDir) }
                        } label: {
                            HStack(spacing: DS.Spacing.sm) {
                                Image(systemName: "bolt.fill")
                                Text("Connect to pi")
                                    .font(DS.body(14, weight: .semibold))
                            }
                            .foregroundStyle(.black)
                            .padding(.horizontal, DS.Spacing.xl)
                            .padding(.vertical, DS.Spacing.md)
                            .background(DS.Gradients.accentLinear)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                            .shadow(color: DS.Colors.accent.opacity(0.4), radius: 16)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.return, modifiers: .command)
                    }
                }

                Spacer()

                // Footer
                Text("Powered by pi · JSON-RPC protocol")
                    .font(DS.mono(10))
                    .foregroundStyle(DS.Colors.textTertiary)
                    .padding(.bottom, DS.Spacing.xl)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

struct SettingsField: View {
    let label: String
    @Binding var value: String
    let placeholder: String
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(DS.mono(9, weight: .semibold))
                .foregroundStyle(DS.Colors.textTertiary)
                .tracking(0.8)

            TextField(placeholder, text: $value)
                .font(DS.mono(12))
                .foregroundStyle(DS.Colors.textPrimary)
                .textFieldStyle(.plain)
                .focused($focused)
                .padding(DS.Spacing.sm)
                .background(DS.Colors.background)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .stroke(focused ? DS.Colors.accent.opacity(0.5) : DS.Colors.border, lineWidth: 1)
                )
        }
    }
}
