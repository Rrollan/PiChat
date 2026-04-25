import AppKit
import Foundation
import UniformTypeIdentifiers

// MARK: - Attachment ingress helpers

/// Normalizes files/images arriving from pasteboard, SwiftUI paste commands and drag & drop.
enum AttachmentIngress {
    static let acceptedAttachmentTypes: [UTType] = [
        .fileURL,
        .url,
        .image,
        .png,
        .jpeg,
        .tiff,
        .gif,
        .data
    ]

    static let acceptedPasteTypes: [UTType] = acceptedAttachmentTypes + [
        .plainText,
        .text
    ]

    static func providerLooksLikeAttachment(_ provider: NSItemProvider) -> Bool {
        provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) ||
        provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) ||
        provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) ||
        provider.canLoadObject(ofClass: NSImage.self)
    }

    static func extractFileURLs(from pasteboard: NSPasteboard) -> [URL] {
        var urls: [URL] = []

        if let nsURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [NSURL] {
            urls.append(contentsOf: nsURLs.compactMap { $0 as URL }.filter(\.isFileURL))
        }

        if let nsURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [NSURL] {
            urls.append(contentsOf: nsURLs.compactMap { $0 as URL }.filter(\.isFileURL))
        }

        if let values = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            urls.append(contentsOf: values.map { URL(fileURLWithPath: expandTilde($0)) })
        }

        let explicitTypes: [NSPasteboard.PasteboardType] = [
            .fileURL,
            .URL,
            NSPasteboard.PasteboardType("public.file-url"),
            NSPasteboard.PasteboardType("public.url"),
            NSPasteboard.PasteboardType("com.apple.pasteboard.promised-file-url")
        ]
        for type in explicitTypes {
            urls.append(contentsOf: fileURLs(fromPasteboardItemString: pasteboard.string(forType: type)))
            if let data = pasteboard.data(forType: type) {
                urls.append(contentsOf: fileURLs(from: data))
            }
        }

        if let plain = pasteboard.string(forType: .string) {
            urls.append(contentsOf: fileURLs(fromPasteboardItemString: plain))
        }

        for item in pasteboard.pasteboardItems ?? [] {
            for type in item.types {
                let raw = type.rawValue
                let uti = UTType(raw)
                let mayContainFileURL = raw.localizedCaseInsensitiveContains("file-url") ||
                    raw.localizedCaseInsensitiveContains("fileurl") ||
                    uti?.conforms(to: .fileURL) == true ||
                    uti?.conforms(to: .url) == true
                guard mayContainFileURL else { continue }

                urls.append(contentsOf: fileURLs(fromPasteboardItemString: item.string(forType: type)))
                if let data = item.data(forType: type) {
                    urls.append(contentsOf: fileURLs(from: data))
                }
            }
        }

        return uniqueExistingFileURLs(urls)
    }

    static func extractImage(from pasteboard: NSPasteboard) -> NSImage? {
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage], let first = images.first {
            return first
        }
        if let image = NSImage(pasteboard: pasteboard) { return image }

        let knownTypes: [NSPasteboard.PasteboardType] = [
            .png,
            .tiff,
            NSPasteboard.PasteboardType("public.jpeg"),
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

    static func loadAttachmentURLs(from providers: [NSItemProvider], completion: @escaping ([URL]) -> Void) {
        let group = DispatchGroup()
        let lock = NSLock()
        var urls: [URL] = []

        func append(_ newURLs: [URL]) {
            guard !newURLs.isEmpty else { return }
            lock.lock()
            urls.append(contentsOf: newURLs)
            lock.unlock()
        }

        for provider in providers {
            let advertisesFile = provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) ||
                provider.hasItemConformingToTypeIdentifier(UTType.url.identifier)

            if advertisesFile {
                group.enter()
                loadFileURLs(from: provider) { loaded in
                    append(loaded)
                    group.leave()
                }
                continue
            }

            if provider.canLoadObject(ofClass: NSImage.self) {
                group.enter()
                _ = provider.loadObject(ofClass: NSImage.self) { object, _ in
                    if let image = object as? NSImage,
                       let url = saveImageToTemporaryFile(image, prefix: "pichat-drop") {
                        append([url])
                    }
                    group.leave()
                }
                continue
            }

            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                group.enter()
                loadImageData(from: provider) { data in
                    if let data,
                       let image = NSImage(data: data),
                       let url = saveImageToTemporaryFile(image, prefix: "pichat-drop") {
                        append([url])
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            completion(uniqueExistingFileURLs(urls))
        }
    }

    static func saveImageToTemporaryFile(_ image: NSImage, prefix: String = "pichat-paste") -> URL? {
        guard let pngData = pngData(from: image) else { return nil }
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString).png")
        do {
            try pngData.write(to: tmp)
            return tmp
        } catch {
            return nil
        }
    }

    private static func loadFileURLs(from provider: NSItemProvider, completion: @escaping ([URL]) -> Void) {
        let typeOrder = [
            UTType.fileURL.identifier,
            UTType.url.identifier,
            "public.file-url",
            "public.url",
            UTType.plainText.identifier
        ]
        guard let type = typeOrder.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) else {
            completion([])
            return
        }

        provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
            completion(fileURLs(fromItemProviderValue: item))
        }
    }

    private static func loadImageData(from provider: NSItemProvider, completion: @escaping (Data?) -> Void) {
        let typeOrder = [
            UTType.png.identifier,
            UTType.jpeg.identifier,
            UTType.tiff.identifier,
            UTType.gif.identifier,
            UTType.image.identifier
        ]
        guard let type = typeOrder.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) else {
            completion(nil)
            return
        }
        provider.loadDataRepresentation(forTypeIdentifier: type) { data, _ in
            completion(data)
        }
    }

    private static func fileURLs(fromItemProviderValue item: NSSecureCoding?) -> [URL] {
        if let url = item as? URL, url.isFileURL { return uniqueExistingFileURLs([url]) }
        if let url = item as? NSURL, let value = url as URL?, value.isFileURL { return uniqueExistingFileURLs([value]) }
        if let data = item as? Data { return fileURLs(from: data) }
        if let string = item as? String { return fileURLs(fromPasteboardItemString: string) }
        return []
    }

    private static func fileURLs(from data: Data) -> [URL] {
        var urls: [URL] = []
        if let url = URL(dataRepresentation: data, relativeTo: nil), url.isFileURL {
            urls.append(url)
        }
        if let string = String(data: data, encoding: .utf8) {
            urls.append(contentsOf: fileURLs(fromPasteboardItemString: string))
        }
        if let string = String(data: data, encoding: .utf16) {
            urls.append(contentsOf: fileURLs(fromPasteboardItemString: string))
        }
        return uniqueExistingFileURLs(urls)
    }

    private static func fileURLs(fromPasteboardItemString rawString: String?) -> [URL] {
        guard let rawString else { return [] }
        let cleaned = rawString
            .replacingOccurrences(of: "\0", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return [] }

        let pieces = cleaned
            .components(separatedBy: CharacterSet.newlines.union(.init(charactersIn: "\r")))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: "\"'"))) }
            .filter { !$0.isEmpty }

        var urls: [URL] = []
        for piece in pieces {
            if let url = URL(string: piece), url.isFileURL {
                urls.append(url)
                continue
            }

            let expanded = expandTilde(piece)
            if expanded.hasPrefix("/") {
                urls.append(URL(fileURLWithPath: expanded))
            }
        }
        return uniqueExistingFileURLs(urls)
    }

    private static func uniqueExistingFileURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        var result: [URL] = []
        for url in urls {
            guard url.isFileURL else { continue }
            let normalized = url.standardizedFileURL
            guard FileManager.default.fileExists(atPath: normalized.path) else { continue }
            let key = normalized.path
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(normalized)
        }
        return result
    }

    private static func expandTilde(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }

    private static func pngData(from image: NSImage) -> Data? {
        if let tiff = image.tiffRepresentation,
           let bmp = NSBitmapImageRep(data: tiff),
           let data = bmp.representation(using: .png, properties: [:]) {
            return data
        }

        var rect = NSRect(origin: .zero, size: image.size)
        if let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
            let rep = NSBitmapImageRep(cgImage: cgImage)
            return rep.representation(using: .png, properties: [:])
        }

        return nil
    }
}
