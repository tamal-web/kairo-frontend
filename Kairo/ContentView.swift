import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: ChatStore

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            if store.activeSession != nil {
                ChatView()
            } else {
                EmptyStateView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SummarizeFileAction"))) { notification in
            if let prompt = notification.object as? String {
                store.newChat()
                store.send(text: prompt)
                
                // If it was called while Assistant panel is open, ensure assistant processes it
                if AssistantPanelManager.shared.viewModel.phase != .idle {
                    AssistantPanelManager.shared.viewModel.submittedText = "Summarising file attached..."
                    AssistantPanelManager.shared.viewModel.inputText = ""
                    AssistantPanelManager.shared.viewModel.phase = .asking
                    AssistantPanelManager.shared.resizePanel(to: .asking)
                }
            }
        }
    }
}
