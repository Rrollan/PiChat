import SwiftUI

// MARK: - Main Content View

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ZStack {
            if state.isConnected {
                MainLayout()
            } else {
                LoadingView()
                    .onAppear {
                        if !state.isStarting && !state.isConnected {
                            Task {
                                await state.connect()
                            }
                        }
                    }
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
    @AppStorage("ui.showRightPanel") private var showRightPanel = true

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
            ChatView()
            if showRightPanel {
                RightPanelView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(DS.Colors.background)
        .frame(minWidth: 900, minHeight: 600)
        .overlay(alignment: .trailing) {
            if !showRightPanel {
                Button {
                    withAnimation { showRightPanel = true }
                } label: {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.Colors.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(DS.Colors.surfaceElevated)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(DS.Colors.border, lineWidth: 1))
                        .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
                .help("Open right panel")
            }
        }
        .animation(.easeInOut(duration: 0.18), value: showRightPanel)
        // Keyboard shortcuts
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willBecomeActiveNotification)) { _ in
            Task { await state.refreshStats() }
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    @EnvironmentObject var state: AppState
    @State private var dots = 0
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            DS.Gradients.backgroundRadial.ignoresSafeArea()

            VStack(spacing: DS.Spacing.xxxl) {
                ThemedLogo()
                    .frame(width: 72, height: 72)
                    .opacity(0.9)

                VStack(spacing: DS.Spacing.sm) {
                    Text("Starting pi agent")
                        .font(DS.display(18, weight: .semibold))
                        .foregroundStyle(DS.Colors.textPrimary)

                    if let err = state.connectionError {
                        Text(err)
                            .font(DS.mono(13))
                            .foregroundStyle(DS.Colors.red)
                        
                        Button("Retry") {
                            Task { await state.connect() }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(DS.Colors.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.Colors.border, lineWidth: 1))
                        .padding(.top, 8)
                    } else {
                        Text("Initializing RPC connection" + String(repeating: ".", count: dots))
                            .font(DS.mono(13))
                            .foregroundStyle(DS.Colors.textSecondary)
                            .animation(.none, value: dots)
                    }
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .onReceive(timer) { _ in dots = (dots + 1) % 4 }
    }
}

