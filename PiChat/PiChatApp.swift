import SwiftUI

@main
struct PiChatApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
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
}
