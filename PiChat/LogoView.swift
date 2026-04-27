import SwiftUI
import AppKit

enum PiChatLogoStyle {
    case classic
    case mark314
}

struct PiChatLogo: View {
    @Environment(\.colorScheme) private var colorScheme
    var style: PiChatLogoStyle = .classic

    var body: some View {
        let fileName: String = {
            switch style {
            case .classic:
                return colorScheme == .dark ? "pilogo_light" : "pilogo_transparent"
            case .mark314:
                return colorScheme == .dark ? "logo2_transparent" : "logo_transparent"
            }
        }()

        if let url = PiChatResource.url(forResource: fileName, withExtension: "png"),
           let nsImage = NSImage(contentsOf: url) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "questionmark.app.dashed")
                .resizable()
                .scaledToFit()
                .foregroundColor(.red)
        }
    }
}

private enum PiChatResource {
    static func url(forResource name: String, withExtension fileExtension: String) -> URL? {
        if let url = Bundle.main.url(forResource: name, withExtension: fileExtension) {
            return url
        }

        let bundleName = "PiChat_PiChat.bundle"
        var bundleURLs = [Bundle.main.bundleURL.appendingPathComponent(bundleName)]

        if let resourceURL = Bundle.main.resourceURL {
            bundleURLs.append(resourceURL.appendingPathComponent(bundleName))
        }

        if let executableURL = Bundle.main.executableURL {
            bundleURLs.append(executableURL.deletingLastPathComponent().appendingPathComponent(bundleName))
        }

        for bundleURL in bundleURLs {
            guard let bundle = Bundle(url: bundleURL),
                  let url = bundle.url(forResource: name, withExtension: fileExtension) else {
                continue
            }
            return url
        }

        return nil
    }
}
