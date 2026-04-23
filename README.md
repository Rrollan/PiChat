# PiChat ⚡️

**PiChat** is a beautiful, native macOS SwiftUI client for the [pi coding agent](https://github.com/mariozechner/pi-coding-agent). It connects to `pi` via JSON-RPC to provide a powerful, graphical "dark luxury terminal" alternative to the default CLI interface.

![PiChat UI Concept](https://via.placeholder.com/1000x600/0A0A0F/00D4FF?text=PiChat+Native+macOS+Client)

## ✨ Features

- **Native SwiftUI Performance**: Lightning fast, perfectly integrated into macOS.
- **Glass Morphism meets Hacker Terminal**: A beautiful dark theme (`#0A0A0F` background) with electric blue (`#00D4FF`) and soft purple (`#8B5CF6`) accents.
- **Full JSON-RPC Integration**: Communicates seamlessly with the background Node.js `pi` process.
- **Rich Dialog Support**: Intercepts `pi` extensions UI events (Confirms, Selects, Inputs, Editors) and renders them as beautiful native overlay cards.
- **Live Tool Streaming**: Real-time rotating indicators and tool execution streams (visible in the right-hand panel).
- **Drag & Drop**: Drop images or files directly into the input field to send them to the agent.
- **Project Switcher**: Instantly change the working directory (project folder) directly from the Chat Header, which automatically restarts the agent.
- **Session & Stats Tracker**: Tracks tokens, cost, context window utilization, and agent queue length in real-time.

## 🚀 Getting Started

### Prerequisites

1. **macOS 14.0 (Sonoma)** or newer.
2. **Swift & Swift Package Manager** installed (comes with Xcode Command Line Tools).
3. The [pi coding agent](https://github.com/mariozechner/pi-coding-agent) installed globally via npm:
   ```bash
   npm install -g @mariozechner/pi-coding-agent
   ```

### Building & Running

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Rrollan/PiChat.git
   cd PiChat
   ```

2. **Build the app**:
   ```bash
   swift build
   ```

3. **Package the executable** into the macOS `.app` bundle:
   ```bash
   mkdir -p build/PiChat.app/Contents/MacOS
   mkdir -p build/PiChat.app/Contents/Resources
   cp .build/arm64-apple-macosx/debug/PiChat build/PiChat.app/Contents/MacOS/
   cp PiChat/Info.plist build/PiChat.app/Contents/
   ```

4. **Sign the application**:
   ```bash
   codesign --force --deep --sign - build/PiChat.app
   ```

5. **Run**:
   ```bash
   open build/PiChat.app
   ```

## 🏗 Architecture

- `PiRPCClient.swift`: The core JSON-RPC communication layer. It launches `/opt/homebrew/bin/pi --mode rpc --no-session` as a subprocess, patches the `PATH` environment, and reads standard streams asynchronously.
- `AppState.swift`: An `@MainActor ObservableObject` that acts as the single source of truth. It handles message routing, queue updates, UI prompts, and model states.
- `DesignSystem.swift` (DS): Centralized design tokens (colors, gradients, typography, corner radii, and reusable modifiers like `.glassCard()`).
- Modular SwiftUI Views (`SidebarView`, `ChatView`, `RightPanelView`, `DialogsView`).

## 🛠 Usage
- **Change Project**: Click the folder icon in the top right of the Chat View to pick a different directory to work in.
- **Models & Thinking**: Use the sidebar dropdowns to switch AI providers and adjust the reasoning ("Thinking") depth.
- **Keyboard Shortcuts**: Use `Cmd + Enter` to send a message.

## 📜 License
MIT License.
