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
                    FileAttachButton()

                    // Text input
                    ZStack(alignment: .topLeading) {
                        if state.inputText.isEmpty {
                            Text("Message pi agent…  (⌘↵ to send)")
                                .font(DS.body(14))
                                .foregroundStyle(DS.Colors.textTertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }

                        TextEditor(text: $state.inputText)
                            .font(DS.body(14))
                            .foregroundStyle(DS.Colors.textPrimary)
                            .scrollContentBackground(.hidden)
                            .background(.clear)
                            .focused($isFocused)
                            .frame(minHeight: 36, maxHeight: 180)
                            .fixedSize(horizontal: false, vertical: true)
                            .onKeyPress(.return) {
                                // Cmd+Return to send
                                return .ignored
                            }
                    }
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.lg)
                            .fill(DS.Colors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.lg)
                                    .stroke(
                                        isFocused ? DS.Colors.accent.opacity(0.5) : DS.Colors.border,
                                        lineWidth: 1
                                    )
                            )
                    )
                    .animation(.easeInOut(duration: 0.15), value: isFocused)
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

                    // Send / Abort button
                    SendAbortButton()
                }
                .padding(.horizontal, DS.Spacing.xl)
            }
            .padding(.vertical, DS.Spacing.md)
            .background(DS.Colors.surface)
        }
        .onAppear { isFocused = true }
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
    @EnvironmentObject var state: AppState
    @State private var isHovered = false

    var body: some View {
        Button {
            openFilePanel()
        } label: {
            Image(systemName: "paperclip")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isHovered ? DS.Colors.accent : DS.Colors.textTertiary)
                .frame(width: 34, height: 34)
                .background(isHovered ? DS.Colors.accentDim : DS.Colors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .stroke(isHovered ? DS.Colors.accent.opacity(0.4) : DS.Colors.border, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .help("Attach files (or drag & drop)")
    }

    private func openFilePanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            .image, .pdf, .plainText, .sourceCode, .json,
            .init(filenameExtension: "md")!, .init(filenameExtension: "ts")!,
            .init(filenameExtension: "swift")!, .init(filenameExtension: "py")!
        ]
        if panel.runModal() == .OK {
            panel.urls.forEach { state.addFile(url: $0) }
        }
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
                        .frame(width: 34, height: 34)
                    ProgressView()
                        .controlSize(.small)
                        .colorScheme(.dark)
                } else if state.isStreaming {
                    // Stop button
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .fill(DS.Colors.red.opacity(0.9))
                        .frame(width: 34, height: 34)
                    Image(systemName: "stop.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    // Send button
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .fill(canSend ? AnyShapeStyle(DS.Gradients.accentLinear) : AnyShapeStyle(DS.Colors.border))
                        .frame(width: 34, height: 34)
                        .shadow(color: canSend ? DS.Colors.accent.opacity(0.3) : .clear, radius: 8)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(canSend ? .black : DS.Colors.textTertiary)
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
