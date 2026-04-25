// AssistantView.swift
import SwiftUI

// MARK: - AssistantView

struct AssistantView: View {
    let manager: AssistantPanelManager
    @ObservedObject var viewModel: AssistantViewModel
    @EnvironmentObject var store: ChatStore
    @ObservedObject private var speechManager = SpeechManager.shared

    @FocusState private var inputFocused: Bool

    private var latestAssistant: Message? {
        store.activeSession?.messages.last(where: { $0.role == .assistant })
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            if viewModel.phase != .idle {
                Divider().opacity(0.5)
                responseArea
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
        )
        // ── Shadow is the ONLY shadow — NSPanel.hasShadow is false ───────────
        // Two-layer shadow mimics macOS floating-panel depth without the AppKit
        // rectangular-frame halo. The outer shadow needs enough bleed room so
        // increase .padding() below to match the largest radius (36 pt → 48 pt).
        
        .shadow(color: .black.opacity(0.38), radius: 45, x: 0, y: 14) 
//        .shadow(color: .black.opacity(0.10), radius:  8, x: 0, y:  3)
        
        // ── Extra padding gives the shadow room to render ─────────────────────
        // Without sufficient padding the shadow is clipped by the hosting view's
        // bounds and the cut-off edge re-appears as a hard dark line.
        .padding(48)
        .onChange(of: viewModel.focusTrigger) { _, _ in
            inputFocused = true
        }
        .onChange(of: store.isStreaming) { _, streaming in
            if streaming, viewModel.phase == .asking {
                viewModel.phase = .responding
                manager.resizePanel(to: .responding)
            } else if !streaming, viewModel.phase == .responding {
                viewModel.phase = .done
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            Group {
                if viewModel.phase == .idle {
                    TextField("Ask Kairo anything…", text: $viewModel.inputText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 17, weight: .regular))
                        .focused($inputFocused)
                        .onSubmit { submit() }
                } else {
                    Text(viewModel.submittedText)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer(minLength: 0)

            Group {
                if speechManager.isSpeaking {
                    Button(action: { speechManager.stopSpeech() }) {
                        Image(systemName: "speaker.slash.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.pink)
                    }
                    .buttonStyle(.plain)
                    .help("Stop reading")
                    .padding(.trailing, 2)
                    .transition(.opacity.combined(with: .scale))
                    .animation(.spring(), value: speechManager.isSpeaking)
                }

                switch viewModel.phase {
                case .idle:
                    Text("⌃Space")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 5))

                case .asking, .responding:
                    TypingIndicator()
                        .scaleEffect(0.75)
                        .frame(width: 36, height: 16)

                case .done:
                    Button { manager.hide() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Close  (Esc)")
                }
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 64)
    }

    // MARK: - Response Area

    private var responseArea: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if let msg = latestAssistant {

                        if !msg.content.isEmpty {
                            MarkdownTextView(text: msg.content)
                                .padding(.horizontal, 20)
                                .padding(.top, 14)
                                .padding(.bottom, msg.isStreaming ? 0 : 6)
                                .id("responseText")
                        }

                        if msg.isStreaming {
                            StreamingDot()
                                .padding(.horizontal, 20)
                                .padding(.top, 6)
                                .padding(.bottom, 4)
                        }

                        if msg.content.isEmpty {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Thinking…")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                        }

                        if let files = msg.toolFiles, !files.isEmpty {
                            FilePreviewList(filePaths: files)
                                .padding(.horizontal, 20)
                                .padding(.top, 10)
                        }

                        if let apps = msg.toolApps, !apps.isEmpty {
                            AppGridView(apps: apps)
                                .padding(.horizontal, 20)
                                .padding(.top, 10)
                        }

                        if viewModel.phase == .done {
                            HStack {
                                Spacer()
                                Text("Press esc to close")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.quaternary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, 12)
                        }

                    } else if viewModel.phase == .asking {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Thinking…")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: latestAssistant?.content) { _, _ in
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("responseText", anchor: .bottom)
                    }
                }
            }
        }
        .frame(maxHeight: 370)
    }

    // MARK: - Submit

    private func submit() {
        let text = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !store.isStreaming else { return }

        viewModel.submittedText = text
        viewModel.inputText     = ""
        viewModel.phase         = .asking
        manager.resizePanel(to: .asking)

        store.newChat()
        store.send(text: text)
    }
}
