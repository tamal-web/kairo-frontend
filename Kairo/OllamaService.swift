import Foundation


@MainActor
class KairoService: ObservableObject {
    static let shared = KairoService()

    /// Backend AI default base URL.
    var baseURL: String = "http://127.0.0.1:8000"

    func fetchModels() async throws -> [KairoModel] {
        // Dummy model to represent our LangGraph Agent.
        return [KairoModel(name: "agentic-ai", modifiedAt: nil, size: nil)]
    }

    func streamChat(
        messages: [Message],
        model: String,
        onToken: @escaping (String) -> Void,
        onDone: @escaping ([String]?, [AppInfo]?) -> Void,
        onError: @escaping (Error) -> Void
    ) -> Task<Void, Never> {
        return Task {
            do {
                guard let url = URL(string: "\(baseURL)/api/chat") else {
                    throw URLError(.badURL)
                }

                // Convert the message history into the format our FastAPI expects
                let mappedMessages = messages.map { msg -> [String: String] in
                    return ["role": msg.role.rawValue, "content": msg.content]
                }

                let payload: [String: Any] = [
                    "messages": mappedMessages
                ]

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                // Tool calls (e.g. file search) can be slow — use a generous timeout
                request.timeoutInterval = 300

                let session = URLSession(configuration: {
                    let c = URLSessionConfiguration.default
                    c.timeoutIntervalForRequest = 300
                    c.timeoutIntervalForResource = 300
                    return c
                }())
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let errStr = String(data: data, encoding: .utf8) ?? "Unknown Server Error"
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
                    throw NSError(domain: "BackendService", code: statusCode,
                                  userInfo: [NSLocalizedDescriptionKey: errStr])
                }

                var toolFiles: [String]? = nil
                var toolApps: [AppInfo]? = nil
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let reply = json["response"] as? String {
                        onToken(reply)
                    }
                    if let files = json["tool_files"] as? [String], !files.isEmpty {
                        toolFiles = files
                    }
                    if let rawApps = json["tool_apps"] as? [[String: String]], !rawApps.isEmpty {
                        toolApps = rawApps.compactMap { dict in
                            guard let name = dict["name"], let path = dict["path"] else { return nil }
                            return AppInfo(name: name, path: path)
                        }
                    }
                }

                onDone(toolFiles, toolApps)
            } catch {
                if !Task.isCancelled {
                    onError(error)
                }
            }
        }
    }

    func generateTitle(for firstMessage: String, model: String) async -> String {
        return "Agent Conversation"
    }

    func isReachable() async -> Bool {
        return true
    }
}
