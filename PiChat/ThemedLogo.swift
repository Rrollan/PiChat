import SwiftUI
import AppKit

struct ThemedLogo: View {
    var body: some View {
        if let path = Bundle.module.path(forResource: "sparkle_logo", ofType: "png"),
           let nsImage = NSImage(contentsOfFile: path) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
        } else if let fallbackPath = Bundle.module.path(forResource: "pilogo_light", ofType: "png"),
                  let fallback = NSImage(contentsOfFile: fallbackPath) {
            Image(nsImage: fallback)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "sparkles")
                .resizable()
                .scaledToFit()
                .foregroundStyle(DS.Colors.accent)
        }
    }
}
