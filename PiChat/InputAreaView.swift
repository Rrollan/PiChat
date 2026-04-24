import SwiftUI
import UniformTypeIdentifiers

// MARK: - Input Area

struct InputAreaView: View {
    @EnvironmentObject var state: AppState
    @State private var isDropTargeted = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Divider().background(DS.Colors.border)

            VStack(spacing: DS.Spacing.sm) {
                // Attached files
                if !state.attachedFiles.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Spacing.xs) {
                            ForEach(state.attachedFiles) { att in
                                AttachmentChip(attachment: att, removable: true) {
                                    state.removeAttachment(id: att.id)
                                }
                            }
                        }
                        .padding(.horizontal, DS.Spacing.xl)
                    }
                }

                // Input row
                HStack(alignment: .bottom, spacing: DS.Spacing.sm) {
                    // File attach button
                    FileAttachButton {
                        openFileImporter()
                    }

                    // Text input
                    TextField(
                        "",
                        text: $state.inputText,
                        prompt: Text("Message pi agent…  (⌘↵ to send)").foregroundColor(DS.Colors.textTertiary),
                        axis: .vertical
                    )
                    .textFieldStyle(.plain)
                    .font(DS.body(14))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .focused($isFocused)
                    .lineLimit(1...10)
                    .frame(minHeight: 30)
                    .padding(.vertical, 2)

                    // Send / Abort button
                    SendAbortButton()
                }
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .fill(DS.Colors.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .stroke(
                            isFocused ? AnyShapeStyle(DS.Gradients.accentLinear) : AnyShapeStyle(DS.Colors.border),
                            lineWidth: isFocused ? 1.5 : 1
                        )
                )
                .shadow(color: isFocused ? DS.Colors.accent.opacity(0.15) : .clear, radius: 8, x: 0, y: 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFocused)
                .onDrop(of: [UTType.fileURL, UTType.image], isTargeted: $isDropTargeted) { providers in
                    handleDrop(providers: providers)
                    return true
                }
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .stroke(DS.Colors.accent.opacity(0.5), lineWidth: 2)
                        .opacity(isDropTargeted ? 1 : 0)
                        .animation(.easeInOut(duration: 0.15), value: isDropTargeted)
                )
                .padding(.horizontal, DS.Spacing.xl)
            }
            .padding(.vertical, DS.Spacing.md)
            .background(DS.Colors.surface)
        }
        .onAppear { isFocused = true }
    }

    private func openFileImporter() {
        let urls = ScriptFilePicker.pickFiles(prompt: "Attach Files")
        if urls.isEmpty {
            state.show(notification: AppNotification(message: "Выбор файлов отменён", type: .warning))
            return
        }

        for url in urls {
            let hasAccess = url.startAccessingSecurityScopedResource()
            state.addFile(url: url)
            if hasAccess { url.stopAccessingSecurityScopedResource() }
        }
        state.show(notification: AppNotification(message: "Добавлено файлов: \(urls.count)", type: .success))
    }

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    DispatchQueue.main.async { state.addFile(url: url) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, _ in
                    if let data = item as? Data,
                       let image = NSImage(data: data),
                       let tiff = image.tiffRepresentation,
                       let bmp = NSBitmapImageRep(data: tiff),
                       let pngData = bmp.representation(using: .png, properties: [:]) {
                        let tmp = FileManager.default.temporaryDirectory
                            .appendingPathComponent(UUID().uuidString + ".png")
                        try? pngData.write(to: tmp)
                        DispatchQueue.main.async { state.addFile(url: tmp) }
                    } else if let url = item as? URL {
                        DispatchQueue.main.async { state.addFile(url: url) }
                    }
                }
            }
        }
    }
}

// MARK: - File Attach Button

struct FileAttachButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) { 
            Image(systemName: "paperclip")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isHovered ? DS.Colors.accent : DS.Colors.textTertiary)
                .frame(width: 30, height: 30)
                .background(isHovered ? DS.Colors.accentDim : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .stroke(isHovered ? DS.Colors.accent.opacity(0.4) : DS.Colors.border.opacity(0.6), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .help("Attach files (or drag & drop)")
    }
}

// MARK: - Send / Abort Button

struct SendAbortButton: View {
    @EnvironmentObject var state: AppState
    @State private var isHovered = false

    var canSend: Bool {
        !state.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !state.attachedFiles.isEmpty
    }

    var body: some View {
        Button {
            if state.isStreaming || state.isWaitingForResponse {
                Task { await state.abortCurrentOperation() }
            } else if canSend {
                Task { await state.sendMessage() }
            }
        } label: {
            ZStack {
                if state.isWaitingForResponse {
                    // Loading spinner
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .fill(DS.Colors.border)
                        .frame(width: 30, height: 30)
                    ProgressView()
                        .controlSize(.small)
                        .colorScheme(.dark)
                } else if state.isStreaming {
                    // Stop button
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .fill(DS.Colors.red.opacity(0.9))
                        .frame(width: 30, height: 30)
                    Image(systemName: "stop.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    // Send button
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .fill(canSend ? AnyShapeStyle(DS.Gradients.accentLinear) : AnyShapeStyle(DS.Colors.border))
                        .frame(width: 30, height: 30)
                        .shadow(color: canSend ? DS.Colors.accent.opacity(0.3) : .clear, radius: 8)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(canSend ? .white : DS.Colors.textTertiary)
                }
            }
            .scaleEffect(isHovered ? 1.05 : 1)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.spring(response: 0.2), value: isHovered)
        .animation(.spring(response: 0.25), value: state.isStreaming)
        .keyboardShortcut(.return, modifiers: .command)
        .disabled(!canSend && !state.isStreaming)
    }
}
