import SwiftUI

@main
struct KairoApp: App {
    @StateObject private var store = ChatStore()
    // Hold a strong reference so the manager (and panel) live for the app lifetime
    private let assistantManager = AssistantPanelManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 860, minHeight: 560)
                .onAppear {
                    // Register Ctrl+Space global hotkey via Carbon and link it to the panel.
                    // NOTE: The CommandGroup below intentionally does NOT duplicate this shortcut.
                    //       A SwiftUI .keyboardShortcut on a Command competes with the Carbon
                    //       hotkey and can silently eat the event when the menu bar is scanned,
                    //       so we rely solely on HotkeyManager (Carbon) for the hotkey.
                    AssistantPanelManager.shared.setup(store: store)
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Chat") {
                    store.newChat()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            // "Assistant Mode" menu item — no keyboard shortcut assigned here;
            // the Carbon hotkey in HotkeyManager handles Ctrl+Space globally.
            CommandGroup(after: .appInfo) {
                Button("Assistant Panel") {
                    AssistantPanelManager.shared.toggle(store: store)
                }
                // No .keyboardShortcut here — Carbon owns Ctrl+Space
            }
        }
    }
}
