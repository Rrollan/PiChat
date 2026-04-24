import SwiftUI

@main
struct PiChatApp: App {
    @StateObject private var appState = AppState()
    @AppStorage("ui.themeMode") private var themeMode = "system"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(preferredColorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Session") {
                    Task { await appState.startNewSession() }
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Compact Context") {
                    Task { await appState.compact() }
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            }

            CommandGroup(after: .appSettings) {
                Button("Disconnect") {
                    appState.disconnect()
                }
                .disabled(!appState.isConnected)
            }
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch themeMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}
