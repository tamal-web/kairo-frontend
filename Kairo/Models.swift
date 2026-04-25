import Foundation
import SwiftUI

// MARK: - App Info (from list_installed_apps tool)

struct AppInfo: Codable, Equatable, Identifiable {
    var id: String { path }
    let name: String
    let path: String
}

// MARK: - Message

struct Message: Identifiable, Codable, Equatable {
    let id: UUID
    var role: Role
    var content: String
    var timestamp: Date
    var isStreaming: Bool
    /// File paths returned by the search_file_by_name tool, if any.
    var toolFiles: [String]?
    /// Apps returned by the list_installed_apps tool, if any.
    var toolApps: [AppInfo]?

    enum Role: String, Codable {
        case user, assistant, system
    }

    init(id: UUID = UUID(), role: Role, content: String, timestamp: Date = Date(),
         isStreaming: Bool = false, toolFiles: [String]? = nil, toolApps: [AppInfo]? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.toolFiles = toolFiles
        self.toolApps = toolApps
    }
}


// MARK: - Chat Session

struct ChatSession: Identifiable, Codable {
    let id: UUID
    var title: String
    var messages: [Message]
    var model: String
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String = "New Chat", messages: [Message] = [], model: String = "llama3.2") {
        self.id = id
        self.title = title
        self.messages = messages
        self.model = model
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var lastMessage: Message? { messages.last }

    var preview: String {
        messages.last(where: { $0.role == .user })?.content ?? "No messages yet"
    }
}

// MARK: - Kairo Models

struct KairoModel: Identifiable, Codable {
    var id: String { name }
    let name: String
    let modifiedAt: String?
    let size: Int64?

    enum CodingKeys: String, CodingKey {
        case name
        case modifiedAt = "modified_at"
        case size
    }

    var displayName: String {
        name.components(separatedBy: ":").first ?? name
    }

    var sizeString: String {
        guard let size = size else { return "" }
        let gb = Double(size) / 1_000_000_000
        if gb >= 1.0 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(size) / 1_000_000
        return String(format: "%.0f MB", mb)
    }
}

struct KairoModelsResponse: Codable {
    let models: [KairoModel]
}

// MARK: - Speech Manager

class SpeechManager: ObservableObject {
    static let shared = SpeechManager()
    
    @Published var isSpeaking: Bool = false
    private var timer: Timer?
    
    private let pidFilePath = "/tmp/kairo_speech.pid"
    
    init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let exists = FileManager.default.fileExists(atPath: self.pidFilePath)
            if self.isSpeaking != exists {
                DispatchQueue.main.async {
                    self.isSpeaking = exists
                }
            }
        }
    }
    
    func stopSpeech() {
        if let pidString = try? String(contentsOfFile: pidFilePath, encoding: .utf8),
           let pid = Int32(pidString.trimmingCharacters(in: .whitespacesAndNewlines)) {
            kill(pid, SIGTERM)
            try? FileManager.default.removeItem(atPath: pidFilePath)
        }
        
        // Optimistically update UI
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}
