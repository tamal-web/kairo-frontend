import Foundation
import SwiftUI

@MainActor
class ChatStore: ObservableObject {
    @Published var sessions: [ChatSession] = []
    @Published var activeSessionID: UUID?
    @Published var availableModels: [KairoModel] = []
    @Published var selectedModel: String = ""
    @Published var isLoadingModels: Bool = false
    @Published var agentStatus: KairoStatus = .unknown
    @Published var isStreaming: Bool = false

    private var streamTask: Task<Void, Never>?
    private let persistKey = "chat_sessions_v1"

    enum KairoStatus {
        case unknown, connected, disconnected
        var color: Color {
            switch self {
            case .unknown: return .yellow
            case .connected: return .green
            case .disconnected: return .red
            }
        }
        var label: String {
            switch self {
            case .unknown: return "Checking…"
            case .connected: return "Connected"
            case .disconnected: return "Offline"
            }
        }
    }

    var activeSession: ChatSession? {
        get { sessions.first(where: { $0.id == activeSessionID }) }
    }

    private var activeSessionIndex: Int? {
        sessions.firstIndex(where: { $0.id == activeSessionID })
    }

    // MARK: - Init

    init() {
        loadSessions()
        if sessions.isEmpty { newChat() }
        Task { await checkStatus() }
        Task { await loadModels() }
    }

    // MARK: - Session Management

    func newChat() {
        let session = ChatSession(model: selectedModel)
        sessions.insert(session, at: 0)
        activeSessionID = session.id
        saveSessions()
    }

    func selectSession(_ id: UUID) {
        cancelStream()
        activeSessionID = id
    }

    func deleteSession(_ id: UUID) {
        if id == activeSessionID { cancelStream() }
        sessions.removeAll { $0.id == id }
        if activeSessionID == id {
            activeSessionID = sessions.first?.id
        }
        if sessions.isEmpty { newChat() }
        saveSessions()
    }

    func renameSession(_ id: UUID, title: String) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[idx].title = title
        saveSessions()
    }

    // MARK: - Sending Messages

    func send(text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let idx = activeSessionIndex else { return }

        let userMsg = Message(role: .user, content: text)
        sessions[idx].messages.append(userMsg)
        sessions[idx].updatedAt = Date()

        // Auto-generate title after first user message
        if sessions[idx].messages.filter({ $0.role == .user }).count == 1 {
            let model = sessions[idx].model
            let sessionID = sessions[idx].id
            Task {
                let title = await KairoService.shared.generateTitle(for: text, model: model)
                if let i = self.sessions.firstIndex(where: { $0.id == sessionID }) {
                    self.sessions[i].title = title
                    self.saveSessions()
                }
            }
        }

        // Add empty assistant message for streaming
        var assistantMsg = Message(role: .assistant, content: "", isStreaming: true)
        sessions[idx].messages.append(assistantMsg)
        let assistantID = assistantMsg.id
        isStreaming = true

        let model = sessions[idx].model
        let history = sessions[idx].messages.filter { !$0.isStreaming }

        streamTask = KairoService.shared.streamChat(
            messages: history,
            model: model,
            onToken: { [weak self] token in
                Task { @MainActor [weak self] in
                    guard let self = self,
                          let i = self.sessions.firstIndex(where: { $0.id == self.activeSessionID }),
                          let j = self.sessions[i].messages.firstIndex(where: { $0.id == assistantID })
                    else { return }
                    self.sessions[i].messages[j].content += token
                }
            },
            onDone: { [weak self] toolFiles, toolApps in
                Task { @MainActor [weak self] in
                    guard let self = self,
                          let i = self.sessions.firstIndex(where: { $0.id == self.activeSessionID }),
                          let j = self.sessions[i].messages.firstIndex(where: { $0.id == assistantID })
                    else { return }
                    self.sessions[i].messages[j].isStreaming = false
                    self.sessions[i].messages[j].toolFiles = toolFiles
                    self.sessions[i].messages[j].toolApps = toolApps
                    self.sessions[i].updatedAt = Date()
                    self.isStreaming = false
                    self.saveSessions()
                }
            },
            onError: { [weak self] error in
                Task { @MainActor [weak self] in
                    guard let self = self,
                          let i = self.sessions.firstIndex(where: { $0.id == self.activeSessionID }),
                          let j = self.sessions[i].messages.firstIndex(where: { $0.id == assistantID })
                    else { return }
                    self.sessions[i].messages[j].content = "⚠️ Error: \(error.localizedDescription)"
                    self.sessions[i].messages[j].isStreaming = false
                    self.isStreaming = false
                }
            }
        )
        saveSessions()
    }

    func cancelStream() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        if let idx = activeSessionIndex,
           let j = sessions[idx].messages.lastIndex(where: { $0.isStreaming }) {
            sessions[idx].messages[j].isStreaming = false
            if sessions[idx].messages[j].content.isEmpty {
                sessions[idx].messages.remove(at: j)
            }
        }
    }

    // MARK: - Models

    func loadModels() async {
        isLoadingModels = true
        do {
            let models = try await KairoService.shared.fetchModels()
            availableModels = models
            if !models.isEmpty && !models.contains(where: { $0.name == selectedModel }) {
                selectedModel = models[0].name
            }
        } catch {
            availableModels = []
        }
        isLoadingModels = false
    }

    func checkStatus() async {
        let reachable = await KairoService.shared.isReachable()
        agentStatus = reachable ? .connected : .disconnected
        if reachable { await loadModels() }
    }

    // MARK: - Persistence

    func saveSessions() {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        UserDefaults.standard.set(data, forKey: persistKey)
    }

    func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: persistKey),
              let decoded = try? JSONDecoder().decode([ChatSession].self, from: data)
        else { return }
        sessions = decoded
        activeSessionID = decoded.first?.id
    }

    func clearAllHistory() {
        cancelStream()
        sessions.removeAll()
        saveSessions()
        newChat()
    }
}
