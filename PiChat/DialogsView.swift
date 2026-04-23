import SwiftUI

// MARK: - Extension UI Dialogs

struct ExtensionUIOverlay: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        if let req = state.pendingUIRequest {
            ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Cancel on background tap
                        state.rpc.sendExtensionUIResponse(id: req.id, cancelled: true)
                        state.pendingUIRequest = nil
                    }

                switch req.method {
                case "confirm":
                    ConfirmDialog(request: req)
                case "select":
                    SelectDialog(request: req)
                case "input":
                    InputDialog(request: req)
                case "editor":
                    EditorDialog(request: req)
                default:
                    EmptyView()
                }
            }
            .transition(.opacity)
        }
    }
}

// MARK: - Confirm Dialog

struct ConfirmDialog: View {
    let request: ExtensionUIRequest
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            // Icon
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(DS.Colors.accent)

            VStack(spacing: DS.Spacing.sm) {
                if let title = request.title {
                    Text(title)
                        .font(DS.display(18, weight: .bold))
                        .foregroundStyle(DS.Colors.textPrimary)
                }
                if let msg = request.message {
                    Text(msg)
                        .font(DS.body(14))
                        .foregroundStyle(DS.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            HStack(spacing: DS.Spacing.md) {
                DialogButton(title: "Cancel", style: .secondary) {
                    state.rpc.sendExtensionUIResponse(id: request.id, confirmed: false)
                    state.pendingUIRequest = nil
                }
                DialogButton(title: "Confirm", style: .primary) {
                    state.rpc.sendExtensionUIResponse(id: request.id, confirmed: true)
                    state.pendingUIRequest = nil
                }
            }
        }
        .padding(DS.Spacing.xxxl)
        .frame(width: 360)
        .glassCard(radius: DS.Radius.xl, border: DS.Colors.accent.opacity(0.3), glow: DS.Colors.accent.opacity(0.15))
    }
}

// MARK: - Select Dialog

struct SelectDialog: View {
    let request: ExtensionUIRequest
    @EnvironmentObject var state: AppState
    @State private var selected: String? = nil

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            if let title = request.title {
                Text(title)
                    .font(DS.display(16, weight: .bold))
                    .foregroundStyle(DS.Colors.textPrimary)
            }

            VStack(spacing: 4) {
                ForEach(request.options ?? [], id: \.self) { option in
                    SelectOption(text: option, isSelected: selected == option) {
                        selected = option
                    }
                }
            }

            HStack(spacing: DS.Spacing.md) {
                DialogButton(title: "Cancel", style: .secondary) {
                    state.rpc.sendExtensionUIResponse(id: request.id, cancelled: true)
                    state.pendingUIRequest = nil
                }
                DialogButton(title: "Select", style: .primary) {
                    state.rpc.sendExtensionUIResponse(id: request.id, value: selected)
                    state.pendingUIRequest = nil
                }
                .disabled(selected == nil)
            }
        }
        .padding(DS.Spacing.xl)
        .frame(width: 380)
        .glassCard(radius: DS.Radius.xl, border: DS.Colors.border, glow: DS.Colors.glowBlue)
    }
}

struct SelectOption: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(DS.body(13))
                    .foregroundStyle(isSelected ? DS.Colors.accent : DS.Colors.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DS.Colors.accent)
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(isSelected ? DS.Colors.accentDim : isHovered ? DS.Colors.border.opacity(0.4) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}

// MARK: - Input Dialog

struct InputDialog: View {
    let request: ExtensionUIRequest
    @EnvironmentObject var state: AppState
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            if let title = request.title {
                Text(title)
                    .font(DS.display(16, weight: .bold))
                    .foregroundStyle(DS.Colors.textPrimary)
            }

            TextField(request.placeholder ?? "Enter value…", text: $text)
                .font(DS.body(14))
                .foregroundStyle(DS.Colors.textPrimary)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .padding(DS.Spacing.md)
                .background(DS.Colors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .stroke(isFocused ? DS.Colors.accent.opacity(0.5) : DS.Colors.border, lineWidth: 1)
                )
                .onSubmit {
                    state.rpc.sendExtensionUIResponse(id: request.id, value: text)
                    state.pendingUIRequest = nil
                }

            HStack(spacing: DS.Spacing.md) {
                DialogButton(title: "Cancel", style: .secondary) {
                    state.rpc.sendExtensionUIResponse(id: request.id, cancelled: true)
                    state.pendingUIRequest = nil
                }
                DialogButton(title: "OK", style: .primary) {
                    state.rpc.sendExtensionUIResponse(id: request.id, value: text)
                    state.pendingUIRequest = nil
                }
            }
        }
        .padding(DS.Spacing.xl)
        .frame(width: 380)
        .glassCard(radius: DS.Radius.xl, border: DS.Colors.border, glow: DS.Colors.glowBlue)
        .onAppear { isFocused = true }
    }
}

// MARK: - Editor Dialog

struct EditorDialog: View {
    let request: ExtensionUIRequest
    @EnvironmentObject var state: AppState
    @State private var text: String
    @FocusState private var isFocused: Bool

    init(request: ExtensionUIRequest) {
        self.request = request
        _text = State(initialValue: request.prefill ?? "")
    }

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            HStack {
                if let title = request.title {
                    Text(title)
                        .font(DS.display(16, weight: .bold))
                        .foregroundStyle(DS.Colors.textPrimary)
                }
                Spacer()
            }

            TextEditor(text: $text)
                .font(DS.mono(12))
                .foregroundStyle(DS.Colors.textPrimary)
                .scrollContentBackground(.hidden)
                .background(DS.Colors.surfaceElevated)
                .focused($isFocused)
                .frame(height: 200)
                .padding(DS.Spacing.sm)
                .background(DS.Colors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .stroke(isFocused ? DS.Colors.accent.opacity(0.5) : DS.Colors.border, lineWidth: 1)
                )

            HStack(spacing: DS.Spacing.md) {
                DialogButton(title: "Cancel", style: .secondary) {
                    state.rpc.sendExtensionUIResponse(id: request.id, cancelled: true)
                    state.pendingUIRequest = nil
                }
                DialogButton(title: "Save", style: .primary) {
                    state.rpc.sendExtensionUIResponse(id: request.id, value: text)
                    state.pendingUIRequest = nil
                }
            }
        }
        .padding(DS.Spacing.xl)
        .frame(width: 520)
        .glassCard(radius: DS.Radius.xl, border: DS.Colors.border, glow: DS.Colors.glowBlue)
        .onAppear { isFocused = true }
    }
}

// MARK: - Dialog Button

struct DialogButton: View {
    enum Style { case primary, secondary }
    let title: String
    let style: Style
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DS.body(13, weight: .semibold))
                .foregroundStyle(style == .primary ? .black : DS.Colors.textSecondary)
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.sm)
                .frame(maxWidth: .infinity)
                .background(
                    Group {
                        if style == .primary {
                            AnyView(DS.Gradients.accentLinear)
                        } else {
                            AnyView(DS.Colors.border)
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .scaleEffect(isHovered ? 1.02 : 1)
                .shadow(color: style == .primary ? DS.Colors.accent.opacity(0.3) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.spring(response: 0.2), value: isHovered)
    }
}

// MARK: - Toast Notification

struct ToastView: View {
    let notification: AppNotification
    @State private var opacity: Double = 0

    var icon: String {
        switch notification.type {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .success: return "checkmark.circle.fill"
        }
    }
    var color: Color {
        switch notification.type {
        case .info: return DS.Colors.accent
        case .warning: return DS.Colors.yellow
        case .error: return DS.Colors.red
        case .success: return DS.Colors.green
        }
    }

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
            Text(notification.message)
                .font(DS.body(12))
                .foregroundStyle(DS.Colors.textPrimary)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.surfaceElevated)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 1))
        .shadow(color: color.opacity(0.15), radius: 12)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) { opacity = 1 }
        }
    }
}
