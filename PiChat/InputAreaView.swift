import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Input Area

struct InputAreaView: View {
    @EnvironmentObject var state: AppState
    @State private var isDropTargeted = false
    @State private var editorHeight: CGFloat = 34
    @State private var pasteEventMonitor: Any?
    @FocusState private var isFocused: Bool

    private let pasteThreshold = 200

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(DS.Colors.border.opacity(0.65))
                .frame(height: 1)

            VStack(spacing: DS.Spacing.sm) {
                if !state.attachedFiles.isEmpty || !state.pastedContents.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Spacing.sm) {
                            ForEach(state.pastedContents) { item in
                                PastedContentPreviewCard(content: item) {
                                    state.removePastedContent(id: item.id)
                                }
                            }
                            ForEach(state.attachedFiles) { att in
                                InputAttachmentPreviewCard(attachment: att) {
                                    state.removeAttachment(id: att.id)
                                }
                            }
                        }
                        .padding(.horizontal, DS.Spacing.md)
                    }
                    .frame(maxWidth: 820)
                }

                HStack(alignment: .center, spacing: DS.Spacing.sm) {
                    FileAttachButton {
                        openFileImporter()
                    }

                    ZStack(alignment: .topLeading) {
                        if state.inputText.isEmpty {
                            Text("Message pi agent…  (⌘↵ to send)")
                                .font(DS.body(15))
                                .foregroundStyle(DS.Colors.textTertiary)
                                .padding(.top, 7)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }

                        PasteAwareTextEditor(
                            text: $state.inputText,
                            height: $editorHeight,
                            isFocused: $isFocused,
                            onSubmit: submitFromEditor,
                            onPasteText: { text in
                                if text.count >= pasteThreshold {
                                    state.addPastedContent(text)
                                    return true
                                }
                                return false
                            },
                            onPasteURLs: { urls in
                                for url in urls { state.addFile(url: url) }
                            },
                            onPasteImage: { image in
                                savePastedImage(image)
                            }
                        )
                        .frame(height: editorHeight)
                    }

                    SendAbortButton()
                }
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, 8)
                .frame(maxWidth: 820)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .fill(DS.Colors.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .stroke(isFocused ? DS.Colors.borderAccent : DS.Colors.border, lineWidth: isFocused ? 1.25 : 1)
                        .allowsHitTesting(false)
                )
                .shadow(color: Color.black.opacity(isFocused ? 0.10 : 0.05), radius: isFocused ? 14 : 8, x: 0, y: 6)
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isFocused)
                .onDrop(of: AttachmentIngress.acceptedAttachmentTypes, isTargeted: $isDropTargeted) { providers in
                    handleAttachmentProviders(providers, source: "Dropped")
                    return true
                }
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                        .foregroundStyle(DS.Colors.accent.opacity(0.5))
                        .opacity(isDropTargeted ? 1 : 0)
                        .animation(.easeInOut(duration: 0.15), value: isDropTargeted)
                        .allowsHitTesting(false)
                )
                .padding(.horizontal, DS.Spacing.xl)
                .onPasteCommand(of: AttachmentIngress.acceptedPasteTypes) { providers in
                    handlePaste(providers: providers)
                }
            }
            .padding(.vertical, DS.Spacing.md)
            .background(DS.Colors.background)
        }
        .onAppear {
            isFocused = true
            installPasteEventMonitor()
        }
        .onDisappear {
            if let pasteEventMonitor {
                NSEvent.removeMonitor(pasteEventMonitor)
                self.pasteEventMonitor = nil
            }
        }
    }

    private func installPasteEventMonitor() {
        guard pasteEventMonitor == nil else { return }
        pasteEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let isPasteShortcut = event.keyCode == 9 && flags.contains(.command) // V
            if isPasteShortcut {
                if let textView = NSApp.keyWindow?.firstResponder as? PasteAwareNSTextView {
                    textView.paste(nil)
                    return nil
                }
                if NSApp.keyWindow?.firstResponder is NSTextView {
                    return event
                }
                if handleClipboardPaste() {
                    return nil
                }
            }
            return event
        }
    }

    @discardableResult
    private func handleClipboardPaste() -> Bool {
        let pasteboard = NSPasteboard.general
        var handled = false

        let urls = AttachmentIngress.extractFileURLs(from: pasteboard)
        if !urls.isEmpty {
            addAttachmentURLs(urls, source: "Pasted")
            handled = true
        }

        if !handled, let image = AttachmentIngress.extractImage(from: pasteboard) {
            savePastedImage(image)
            handled = true
        }

        if let text = pasteboard.string(forType: .string), !handled, text.count >= pasteThreshold {
            state.addPastedContent(text)
            handled = true
        }

        return handled
    }

    private func submitFromEditor() {
        if state.isStreaming || state.isWaitingForResponse {
            Task { await state.abortCurrentOperation() }
            return
        }

        let hasContent = !state.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !state.attachedFiles.isEmpty || !state.pastedContents.isEmpty
        if hasContent {
            Task { await state.sendMessage() }
        }
    }

    private func openFileImporter() {
        let urls = ScriptFilePicker.pickFiles(prompt: "Attach Files")
        if urls.isEmpty {
            state.show(notification: AppNotification(message: "File selection cancelled", type: .warning))
            return
        }

        for url in urls {
            let hasAccess = url.startAccessingSecurityScopedResource()
            state.addFile(url: url)
            if hasAccess { url.stopAccessingSecurityScopedResource() }
        }
        state.show(notification: AppNotification(message: "Files added: \(urls.count)", type: .success))
    }

    private func handlePaste(providers: [NSItemProvider]) {
        if providers.contains(where: AttachmentIngress.providerLooksLikeAttachment) {
            handleAttachmentProviders(providers, source: "Pasted")
            return
        }

        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }) else { return }
        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
            let text: String?
            if let value = item as? String {
                text = value
            } else if let data = item as? Data {
                text = String(data: data, encoding: .utf8)
            } else {
                text = nil
            }
            guard let text else { return }
            DispatchQueue.main.async {
                if text.count >= pasteThreshold {
                    state.addPastedContent(text)
                } else {
                    state.inputText += text
                }
            }
        }
    }

    private func savePastedImage(_ image: NSImage) {
        guard let tmp = AttachmentIngress.saveImageToTemporaryFile(image, prefix: "pichat-paste") else {
            DispatchQueue.main.async {
                state.show(notification: AppNotification(message: "Could not read pasted image", type: .warning))
            }
            return
        }
        DispatchQueue.main.async {
            addAttachmentURLs([tmp], source: "Pasted")
        }
    }

    private func handleAttachmentProviders(_ providers: [NSItemProvider], source: String) {
        AttachmentIngress.loadAttachmentURLs(from: providers) { urls in
            addAttachmentURLs(urls, source: source)
        }
    }

    private func addAttachmentURLs(_ urls: [URL], source: String) {
        guard !urls.isEmpty else {
            state.show(notification: AppNotification(message: "No supported files found", type: .warning))
            return
        }
        for url in urls { state.addFile(url: url) }
        state.show(notification: AppNotification(message: "\(source) files: \(urls.count)", type: .success))
    }
}

// MARK: - Paste-aware multiline editor

struct PasteAwareTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    var isFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void
    let onPasteText: (String) -> Bool
    let onPasteURLs: ([URL]) -> Void
    let onPasteImage: (NSImage) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder

        let textView = PasteAwareNSTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = NSFont.systemFont(ofSize: 15)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.textContainerInset = NSSize(width: 0, height: 7)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 34)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.onSubmit = onSubmit
        textView.onPasteText = onPasteText
        textView.onPasteURLs = onPasteURLs
        textView.onPasteImage = onPasteImage

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? PasteAwareNSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        context.coordinator.recalculateHeight()
        textView.onSubmit = onSubmit
        textView.onPasteText = onPasteText
        textView.onPasteURLs = onPasteURLs
        textView.onPasteImage = onPasteImage
        if isFocused.wrappedValue && nsView.window?.firstResponder !== textView {
            nsView.window?.makeFirstResponder(textView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, height: $height, isFocused: isFocused)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        @Binding var height: CGFloat
        var isFocused: FocusState<Bool>.Binding
        weak var textView: NSTextView?

        init(text: Binding<String>, height: Binding<CGFloat>, isFocused: FocusState<Bool>.Binding) {
            _text = text
            _height = height
            self.isFocused = isFocused
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
            recalculateHeight()
        }

        func recalculateHeight() {
            guard let textView else { return }
            textView.layoutManager?.ensureLayout(for: textView.textContainer!)
            let used = textView.layoutManager?.usedRect(for: textView.textContainer!).height ?? 22
            let inset = textView.textContainerInset.height * 2
            let next = min(max(34, ceil(used + inset)), 96)
            if abs(height - next) > 0.5 {
                DispatchQueue.main.async { self.height = next }
            }
        }

        func textDidBeginEditing(_ notification: Notification) {
            isFocused.wrappedValue = true
        }

        func textDidEndEditing(_ notification: Notification) {
            isFocused.wrappedValue = false
        }
    }
}

enum ClipboardPasteReader {
    static func extractFileURLs(from pasteboard: NSPasteboard) -> [URL] {
        AttachmentIngress.extractFileURLs(from: pasteboard)
    }

    static func extractImage(from pasteboard: NSPasteboard) -> NSImage? {
        AttachmentIngress.extractImage(from: pasteboard)
    }
}

final class PasteAwareNSTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onPasteText: ((String) -> Bool)?
    var onPasteURLs: (([URL]) -> Void)?
    var onPasteImage: ((NSImage) -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 && event.modifierFlags.contains(.command) {
            onSubmit?()
            return
        }
        super.keyDown(with: event)
    }

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        var handled = false

        let urls = AttachmentIngress.extractFileURLs(from: pasteboard)
        if !urls.isEmpty {
            onPasteURLs?(urls)
            handled = true
        }

        if !handled, let image = AttachmentIngress.extractImage(from: pasteboard) {
            onPasteImage?(image)
            handled = true
        }

        if let pastedText = pasteboard.string(forType: .string) {
            if onPasteText?(pastedText) == true {
                handled = true
            } else if !handled {
                super.paste(sender)
                return
            }
        }

        if !handled {
            super.paste(sender)
        }
    }

    private func extractFileURLs(from pasteboard: NSPasteboard) -> [URL] {
        if let nsURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [NSURL], !nsURLs.isEmpty {
            return nsURLs.compactMap { $0 as URL }
        }
        if let values = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            return values.map { URL(fileURLWithPath: $0) }
        }
        if let fileURLString = pasteboard.string(forType: .fileURL),
           let url = URL(string: fileURLString), url.isFileURL {
            return [url]
        }

        var urls: [URL] = []
        for item in pasteboard.pasteboardItems ?? [] {
            for type in item.types {
                let raw = type.rawValue
                let isFileURL = raw == NSPasteboard.PasteboardType.fileURL.rawValue || UTType(raw)?.conforms(to: .fileURL) == true
                guard isFileURL else { continue }
                if let string = item.string(forType: type), let url = URL(string: string), url.isFileURL {
                    urls.append(url)
                } else if let data = item.data(forType: type),
                          let string = String(data: data, encoding: .utf8),
                          let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)),
                          url.isFileURL {
                    urls.append(url)
                }
            }
        }
        return urls
    }

    private func extractImage(from pasteboard: NSPasteboard) -> NSImage? {
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage], let first = images.first {
            return first
        }
        if let image = NSImage(pasteboard: pasteboard) { return image }

        let knownTypes: [NSPasteboard.PasteboardType] = [
            .png,
            .tiff,
            NSPasteboard.PasteboardType("public.png"),
            NSPasteboard.PasteboardType("public.tiff"),
            NSPasteboard.PasteboardType("com.apple.tiff"),
            NSPasteboard.PasteboardType("Apple PNG pasteboard type"),
            NSPasteboard.PasteboardType("NeXT TIFF v4.0 pasteboard type")
        ]
        for type in knownTypes {
            if let data = pasteboard.data(forType: type), let image = NSImage(data: data) {
                return image
            }
        }

        for item in pasteboard.pasteboardItems ?? [] {
            for type in item.types {
                if UTType(type.rawValue)?.conforms(to: .image) == true,
                   let data = item.data(forType: type),
                   let image = NSImage(data: data) {
                    return image
                }
            }
        }
        return nil
    }
}

// MARK: - Clipboard / Attachment Preview Cards

struct PastedContentPreviewCard: View {
    let content: PastedContent
    let onRemove: () -> Void
    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Text(content.content.prefix(260))
                .font(DS.mono(8))
                .foregroundStyle(DS.Colors.textSecondary)
                .lineLimit(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(8)

            LinearGradient(colors: [.clear, DS.Colors.surfaceElevated.opacity(0.98)], startPoint: .top, endPoint: .bottom)

            HStack(spacing: 5) {
                Text("PASTED")
                    .font(DS.mono(9, weight: .semibold))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(DS.Colors.background.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                Text("\(content.wordCount)w")
                    .font(DS.mono(8))
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            .padding(8)

            if isHovered {
                removeButton
                    .padding(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .frame(width: 112, height: 112)
        .background(DS.Colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.border, lineWidth: 1))
        .onHover { isHovered = $0 }
    }

    private var removeButton: some View {
        Button(action: onRemove) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DS.Colors.textPrimary)
                .frame(width: 22, height: 22)
                .background(DS.Colors.background.opacity(0.9))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

struct InputAttachmentPreviewCard: View {
    let attachment: FileAttachment
    let onRemove: () -> Void
    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if attachment.isImage,
               let image = NSImage(contentsOf: attachment.url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 112, height: 112)
                    .clipped()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(DS.Colors.textSecondary)
                    Text(fileExtension)
                        .font(DS.mono(10, weight: .semibold))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            LinearGradient(colors: [.clear, DS.Colors.surfaceElevated.opacity(0.95)], startPoint: .top, endPoint: .bottom)

            Text(attachment.isImage ? "IMAGE" : fileExtension)
                .font(DS.mono(9, weight: .semibold))
                .foregroundStyle(DS.Colors.textPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(DS.Colors.background.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                .padding(8)

            if isHovered {
                removeButton
                    .padding(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .frame(width: 112, height: 112)
        .background(DS.Colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.border, lineWidth: 1))
        .onHover { isHovered = $0 }
        .help(attachment.name)
    }

    private var fileExtension: String {
        let ext = attachment.url.pathExtension.isEmpty ? "FILE" : attachment.url.pathExtension.uppercased()
        return ext.count > 8 ? String(ext.prefix(8)) : ext
    }

    private var removeButton: some View {
        Button(action: onRemove) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DS.Colors.textPrimary)
                .frame(width: 22, height: 22)
                .background(DS.Colors.background.opacity(0.9))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - File Attach Button

struct FileAttachButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) { 
            Image(systemName: "paperclip")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(isHovered ? DS.Colors.accent : DS.Colors.textTertiary)
                .frame(width: 34, height: 34)
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
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    // Send button
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .fill(canSend ? AnyShapeStyle(DS.Colors.borderAccent.opacity(0.55)) : AnyShapeStyle(DS.Colors.border.opacity(0.65)))
                        .frame(width: 34, height: 34)
                        .shadow(color: canSend ? Color.black.opacity(0.08) : .clear, radius: 5)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(canSend ? DS.Colors.textPrimary : DS.Colors.textTertiary)
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
