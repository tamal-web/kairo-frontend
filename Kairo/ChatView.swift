import SwiftUI

struct ChatView: View {
    @EnvironmentObject var store: ChatStore
    @State private var inputText = ""
    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var inputFocused: Bool

    var session: ChatSession? { store.activeSession }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            chatToolbar

            Divider()

            // Messages
            if let session = session {
                if session.messages.isEmpty {
                    WelcomeView()
                } else {
                    messagesScrollView(session: session)
                }
            }

            Divider()

            // Input
            inputArea
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: store.activeSessionID) { _, _ in
            inputText = ""
            inputFocused = true
        }
        .onAppear { inputFocused = true }
    }

    // MARK: - Toolbar

    private var chatToolbar: some View {
        HStack(spacing: 12) {
            // Model picker
            HStack(spacing: 6) {
                Image(systemName: "cpu")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                if store.availableModels.isEmpty {
                    Text(store.selectedModel)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    Picker("", selection: $store.selectedModel) {
                        ForEach(store.availableModels) { model in
                            HStack {
                                Text(model.displayName)
                                if !model.sizeString.isEmpty {
                                    Text(model.sizeString)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tag(model.name)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .font(.system(size: 12))
                    .frame(maxWidth: 180)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 7))

            Spacer()

            // Title
            if let title = session?.title {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Stop button
            if store.isStreaming {
                Button(action: { store.cancelStream() }) {
                    Label("Stop", systemImage: "stop.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            } else {
                // New chat button
                Button(action: { store.newChat() }) {
                    Label("New Chat", systemImage: "square.and.pencil")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("New Chat (⌘N)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Messages

    private func messagesScrollView(session: ChatSession) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(session.messages) { message in
                        MessageRow(message: message)
                            .id(message.id)
                    }
                    // Anchor for auto-scroll
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.vertical, 12)
            }
            .onAppear {
                scrollProxy = proxy
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: session.messages.last?.content) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: session.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

    // MARK: - Input Area

    private var inputArea: some View {
        HStack(alignment: .bottom, spacing: 10) {
            // Text input
            // Text input
            TextField("Message \(store.selectedModel.components(separatedBy: ":").first ?? "AI")…", text: $inputText, axis: .vertical)
                .font(.system(size: 13))
                .textFieldStyle(.plain)
                .focused($inputFocused)
                .lineLimit(1...7)
                .onKeyPress(.return) {
                    if NSEvent.modifierFlags.contains(.shift) {
                        return .ignored
                    }
                    sendMessage()
                    return .handled
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )

            // Send button
            Button(action: sendMessage) {
                ZStack {
                    Circle()
                        .fill(canSend ? Color.accentColor : Color.primary.opacity(0.1))
                        .frame(width: 34, height: 34)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(canSend ? Color.white : Color.primary.opacity(0.3))
                }
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .help("Send (Return)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !store.isStreaming
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !store.isStreaming else { return }
        inputText = ""
        store.send(text: text)  
    }
}

// MARK: - Welcome View

struct WelcomeView: View {
    @EnvironmentObject var store: ChatStore

    let suggestions = [
        ("lightbulb.fill", "Explain quantum computing in simple terms"),
        ("doc.text.fill", "Help me write a professional email"),
        ("swift", "Write a SwiftUI custom button component"),
        ("chart.bar.fill", "Analyze the pros and cons of remote work")
    ]

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)
                Text("How can I help?")
                    .font(.system(size: 22, weight: .semibold))
                Text("Running locally on \(store.selectedModel.components(separatedBy: ":").first ?? "Kairo")")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            // Suggestion chips
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(suggestions, id: \.1) { icon, text in
                    SuggestionButton(icon: icon, text: text) {
                        store.send(text: text)
                    }
                }
            }
            .frame(maxWidth: 520)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SuggestionButton: View {
    let icon: String
    let text: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 16)
                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary.opacity(0.8))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No chat selected")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
