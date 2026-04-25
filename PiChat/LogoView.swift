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

        if let path = Bundle.module.path(forResource: fileName, ofType: "png"),
           let nsImage = NSImage(contentsOfFile: path) {
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
