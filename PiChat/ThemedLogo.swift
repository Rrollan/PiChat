import SwiftUI
import AppKit

struct ThemedLogo: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let fileName = colorScheme == .dark ? "pilogo_light" : "pilogo_transparent"

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
