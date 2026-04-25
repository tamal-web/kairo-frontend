import SwiftUI
import PDFKit

struct MessageRow: View {
    let message: Message
    @State private var isHovered = false
    @State private var copied = false
    @ObservedObject private var speechManager = SpeechManager.shared

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                // Role label
                HStack(spacing: 6) {
                    if !isUser {
                        Image(systemName: "sparkle")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.accentColor)
                        Text("Assistant")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("You")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, isUser ? 0 : 2)

                // Bubble
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if isUser {
                            Text(message.content)
                                .font(.system(size: 13))
                                .textSelection(.enabled)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(BubbleShape(isUser: true))
                        } else {
                            VStack(alignment: .leading, spacing: 0) {
                                if message.isStreaming && message.content.isEmpty {
                                    TypingIndicator()
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                } else {
                                    MarkdownTextView(text: message.content)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                }
                            }
                            .background(Color.primary.opacity(0.06))
                            .clipShape(BubbleShape(isUser: false))
                        }
                    }

                    // Copy button (hover)
                    if isHovered && !message.content.isEmpty && !message.isStreaming {
                        Button(action: copyContent) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(isUser ? Color.white.opacity(0.8) : Color.secondary)
                                .frame(width: 22, height: 22)
                                .background(
                                    Circle()
                                        .fill(isUser ? Color.white.opacity(0.2) : Color.primary.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(6)
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: isHovered)

                // ── File previews from search_file_by_name tool ──────────────
                if let files = message.toolFiles, !files.isEmpty {
                    FilePreviewList(filePaths: files)
                        .padding(.top, 6)
                }

                // ── App grid from list_installed_apps tool ────────────────────
                if let apps = message.toolApps, !apps.isEmpty {
                    AppGridView(apps: apps)
                        .padding(.top, 8)
                }

                // Streaming indicator dot
                if message.isStreaming && !message.content.isEmpty {
                    StreamingDot()
                }

                // Global Speech Stopper
                if !isUser && speechManager.isSpeaking {
                    Button(action: { speechManager.stopSpeech() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.circle.fill")
                            Text("Stop Dictation")
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.pink.opacity(0.8))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .scale))
                    .animation(.spring(), value: speechManager.isSpeaking)
                }
            }
            .frame(maxWidth: isUser ? nil : .infinity, alignment: isUser ? .trailing : .leading)

            if !isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .onHover { isHovered = $0 }
    }

    private func copyContent() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { copied = false }
        }
    }
}

// MARK: - File Preview List

struct FilePreviewList: View {
    let filePaths: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(filePaths, id: \.self) { path in
                FilePreviewCard(filePath: path)
            }
        }
        .frame(maxWidth: 360, alignment: .leading)
    }
}

// MARK: - File Preview Card

struct FilePreviewCard: View {
    let filePath: String
    @State private var isHovered = false
    @State private var nsImage: NSImage? = nil

    private var fileName: String {
        URL(fileURLWithPath: filePath).lastPathComponent
    }

    private var fileExtension: String {
        URL(fileURLWithPath: filePath).pathExtension.lowercased()
    }

    private var isImageFile: Bool {
        ["png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff", "heic", "svg"].contains(fileExtension)
    }

    private var fileIcon: String {
        switch fileExtension {
        case "pdf":                             return "doc.richtext.fill"
        case "py":                              return "chevron.left.forwardslash.chevron.right"
        case "swift":                           return "swift"
        case "js", "ts", "jsx", "tsx":         return "chevron.left.forwardslash.chevron.right"
        case "json":                            return "curlybraces"
        case "md", "txt":                       return "doc.text.fill"
        case "html", "css":                     return "globe"
        case "zip", "tar", "gz", "rar":        return "archivebox.fill"
        case "mp4", "mov", "avi", "mkv":       return "film.fill"
        case "mp3", "wav", "aac", "flac":      return "waveform"
        case "xlsx", "csv":                     return "tablecells.fill"
        case "docx", "doc":                     return "doc.fill"
        case "pptx", "ppt":                     return "chart.bar.doc.horizontal.fill"
        default:                                return "doc.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: revealInFinder) {
                HStack(spacing: 10) {
                    // ── Left: thumbnail or icon ──────────────────────────────────
                    Group {
                        if isImageFile, let img = nsImage {
                            Image(nsImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(iconBackground)
                                    .frame(width: 48, height: 48)
                                Image(systemName: fileIcon)
                                    .font(.system(size: 20))
                                    .foregroundStyle(iconColor)
                            }
                        }
                    }

                    // ── Right: name + path ───────────────────────────────────────
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fileName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(filePath)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }

                    Spacer()

                    // ── Reveal arrow on hover ────────────────────────────────────
                    if isHovered {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.accentColor.opacity(0.7))
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isHovered
                              ? Color.accentColor.opacity(0.07)
                              : Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isHovered ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.08),
                            lineWidth: 1
                        )
                )
                .animation(.easeInOut(duration: 0.15), value: isHovered)
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
            
            // ── AI Summarize action button ────────────────────────────────────
            Button {
                summarizeFile()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                    Text("Summarise file: \(fileName)")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentColor)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.leading, 2)
        }
        .onAppear { loadImageIfNeeded() }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private func summarizeFile() {
        let extracted: String
        let url = URL(fileURLWithPath: filePath)
        if fileExtension == "pdf" {
            if let pdf = PDFDocument(url: url) {
                var fullText = ""
                for i in 0..<pdf.pageCount {
                    if let page = pdf.page(at: i), let text = page.string {
                        fullText += text + "\n"
                    }
                }
                extracted = fullText.isEmpty ? "No text available in PDF." : fullText
            } else {
                extracted = "Could not read PDF."
            }
        } else if isImageFile {
            extracted = "Cannot extract text dynamically from an image file natively right now."
        } else {
            extracted = (try? String(contentsOfFile: filePath, encoding: .utf8)) ?? "Could not read file text. It might be binary."
        }
        
        let trimmed = String(extracted.prefix(150000))
//        let prompt = "Please summarize this document (\(fileName)):\n\n```\n\(trimmed)\n```"
        let prompt = "Please summarize the following text:\n\n```\n\(trimmed)\n```"

        
        // We use NotificationCenter or Environment to ask the store to send a message.
        // Or we can add @EnvironmentObject var store: ChatStore
        NotificationCenter.default.post(name: NSNotification.Name("SummarizeFileAction"), object: prompt)
    }

    private var iconBackground: Color {
        switch fileExtension {
        case "pdf":                             return Color.red.opacity(0.12)
        case "py":                              return Color.blue.opacity(0.12)
        case "swift":                           return Color.orange.opacity(0.12)
        case "js", "ts", "jsx", "tsx":         return Color.yellow.opacity(0.12)
        case "json":                            return Color.purple.opacity(0.12)
        case "md", "txt":                       return Color.gray.opacity(0.12)
        case "html", "css":                     return Color.teal.opacity(0.12)
        case "zip", "tar", "gz", "rar":        return Color.brown.opacity(0.12)
        case "mp4", "mov", "avi", "mkv":       return Color.indigo.opacity(0.12)
        case "mp3", "wav", "aac", "flac":      return Color.pink.opacity(0.12)
        default:                                return Color.secondary.opacity(0.1)
        }
    }

    private var iconColor: Color {
        switch fileExtension {
        case "pdf":                             return .red
        case "py":                              return .blue
        case "swift":                           return .orange
        case "js", "ts", "jsx", "tsx":         return Color(red: 0.8, green: 0.7, blue: 0.0)
        case "json":                            return .purple
        case "md", "txt":                       return .secondary
        case "html", "css":                     return .teal
        case "zip", "tar", "gz", "rar":        return .brown
        case "mp4", "mov", "avi", "mkv":       return .indigo
        case "mp3", "wav", "aac", "flac":      return .pink
        default:                                return .secondary
        }
    }

    private func loadImageIfNeeded() {
        guard isImageFile else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let img = NSImage(contentsOfFile: filePath)
            DispatchQueue.main.async { nsImage = img }
        }
    }

    private func revealInFinder() {
        let url = URL(fileURLWithPath: filePath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

// MARK: - App Grid View

struct AppGridView: View {
    let apps: [AppInfo]

    private let columns = [
        GridItem(.adaptive(minimum: 88, maximum: 110), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(apps.count) app\(apps.count == 1 ? "" : "s")")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(apps) { app in
                    AppCard(app: app)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - App Card

struct AppCard: View {
    let app: AppInfo
    @State private var isHovered = false
    @State private var icon: NSImage? = nil

    var body: some View {
        Button(action: openApp) {
            VStack(spacing: 6) {
                // App icon — real macOS icon loaded from the .app bundle
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: 60, height: 60)
                        .shadow(
                            color: isHovered ? Color.accentColor.opacity(0.35) : .clear,
                            radius: 10, x: 0, y: 4
                        )

                    if let icon = icon {
                        Image(nsImage: icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Image(systemName: "app.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.accentColor.opacity(0.6))
                    }
                }
                .scaleEffect(isHovered ? 1.08 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)

                // App name
                Text(app.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isHovered ? Color.accentColor : Color.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 88)
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
            }
            .frame(width: 88)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .onAppear { loadIcon() }
    }

    private func loadIcon() {
        let path = app.path
        DispatchQueue.global(qos: .userInitiated).async {
            // NSWorkspace gives us the real macOS app icon (same as Finder shows)
            let img = NSWorkspace.shared.icon(forFile: path)
            img.size = NSSize(width: 128, height: 128)
            DispatchQueue.main.async { icon = img }
        }
    }

    private func openApp() {
        // Open the app directly — no tool call needed
        let url = URL(fileURLWithPath: app.path)
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Bubble Shape

struct BubbleShape: Shape {
    let isUser: Bool
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 14
        let smallRadius: CGFloat = 4
        var path = Path()

        if isUser {
            // Top-left, top-right (small), bottom-left, bottom-right (small)
            path.addRoundedRect(in: rect, cornerRadii: .init(
                topLeading: radius, bottomLeading: radius,
                bottomTrailing: smallRadius, topTrailing: radius
            ))
        } else {
            path.addRoundedRect(in: rect, cornerRadii: .init(
                topLeading: smallRadius, bottomLeading: radius,
                bottomTrailing: radius, topTrailing: radius
            ))
        }
        return path
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 7, height: 7)
                    .scaleEffect(phase == i ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.16), value: phase)
            }
        }
        .onAppear {
            phase = 0
            withAnimation { phase = 1 }
        }
    }
}

// MARK: - Streaming Dot

struct StreamingDot: View {
    @State private var opacity = 1.0

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 5, height: 5)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                        opacity = 0.2
                    }
                }
            Text("Generating…")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.leading, 4)
    }
}

// MARK: - Simple Markdown Text View

struct MarkdownTextView: View {
    let text: String

    var body: some View {
        if let attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attributed)
                .font(.system(size: 13))
                .textSelection(.enabled)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(text)
                .font(.system(size: 13))
                .textSelection(.enabled)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
