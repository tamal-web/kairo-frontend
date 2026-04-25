import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: ChatStore
    @State private var searchText = ""
    @State private var showClearConfirm = false
    @State private var editingSessionID: UUID?
    @State private var editTitle = ""

    var filteredSessions: [ChatSession] {
        if searchText.isEmpty { return store.sessions }
        return store.sessions.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.preview.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            sidebarHeader

            Divider()

            // Search
            searchBar

            // Session list
            sessionList

            Divider()

            // Footer
            sidebarFooter
        }
        .background(.ultraThinMaterial)
        .confirmationDialog("Clear all chat history?", isPresented: $showClearConfirm) {
            Button("Clear All", role: .destructive) { store.clearAllHistory() }
            Button("Cancel", role: .cancel) { }
        }
    }

    // MARK: - Header

    private var sidebarHeader: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("Kairo")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            Spacer()
            Button(action: { store.newChat() }) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("New Chat (⌘N)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            TextField("Search chats…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - Session List

    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                if filteredSessions.isEmpty {
                    Text("No chats found")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 24)
                } else {
                    ForEach(filteredSessions) { session in
                        SessionRow(
                            session: session,
                            isActive: session.id == store.activeSessionID,
                            editingID: $editingSessionID,
                            editTitle: $editTitle
                        )
                        .contextMenu {
                            Button("Rename") {
                                editingSessionID = session.id
                                editTitle = session.title
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                store.deleteSession(session.id)
                            }
                        }
                        .onTapGesture {
                            store.selectSession(session.id)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Footer

    private var sidebarFooter: some View {
        VStack(spacing: 0) {
            // Status
            HStack(spacing: 6) {
                Circle()
                    .fill(store.agentStatus.color)
                    .frame(width: 7, height: 7)
                Text(store.agentStatus.label)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: { Task { await store.checkStatus() } }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Refresh connection")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // Clear all
            Button(action: { showClearConfirm = true }) {
                Label("Clear History", systemImage: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: ChatSession
    let isActive: Bool
    @Binding var editingID: UUID?
    @Binding var editTitle: String
    @EnvironmentObject var store: ChatStore

    var isEditing: Bool { editingID == session.id }

    var body: some View {
        HStack(spacing: 10) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.07))
                    .frame(width: 32, height: 32)
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
            }

            // Title + preview
            VStack(alignment: .leading, spacing: 2) {
                if isEditing {
                    TextField("Title", text: $editTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .onSubmit {
                            store.renameSession(session.id, title: editTitle)
                            editingID = nil
                        }
                        .onExitCommand { editingID = nil }
                } else {
                    Text(session.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isActive ? Color.primary : Color.primary.opacity(0.75))
                        .lineLimit(1)
                }

                Text(session.preview)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            // Time
            Text(session.updatedAt.relativeString)
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(isActive ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 9))
    }
}

// MARK: - Date extension

extension Date {
    var relativeString: String {
        let diff = Date().timeIntervalSince(self)
        if diff < 60 { return "now" }
        if diff < 3600 { return "\(Int(diff/60))m" }
        if diff < 86400 { return "\(Int(diff/3600))h" }
        if diff < 604800 { return "\(Int(diff/86400))d" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: self)
    }
}
