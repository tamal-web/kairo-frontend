# OllamaChat for macOS

A native macOS SwiftUI chat app for local AI models running via [Ollama](https://ollama.ai).

## Features

- 💬 **Real-time streaming** — tokens appear as they're generated
- 📚 **Chat history sidebar** — all past sessions persisted locally
- 🤖 **Model picker** — switch between any locally pulled Ollama model
- ✏️ **Auto-generated titles** — AI names each chat from the first message
- 🔍 **Search** — filter chats by title or content
- 📋 **Copy messages** — hover any bubble to copy
- ⌘N — New chat shortcut
- ⛔ **Stop generation** — cancel mid-stream

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15+
- [Ollama](https://ollama.ai) running locally

## Setup

### 1. Install & run Ollama

```bash
# Install via Homebrew
brew install ollama

# Start the server
ollama serve

# Pull a model (in a new terminal)
ollama pull llama3.2
# or
ollama pull mistral
ollama pull phi3
```

### 2. Open in Xcode

```
open OllamaChat.xcodeproj
```

Then press **⌘R** to build and run.

### 3. Entitlements (if needed)

If you get network errors when building for distribution, add an entitlements file:

**OllamaChat.entitlements**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
```

## Project Structure

```
OllamaChat/
├── OllamaChatApp.swift    # App entry, commands
├── Models.swift           # Message, ChatSession, OllamaModel types
├── OllamaService.swift    # Streaming API client
├── ChatStore.swift        # App state + persistence (UserDefaults)
├── ContentView.swift      # NavigationSplitView root
├── SidebarView.swift      # Chat history list
├── ChatView.swift         # Message thread + input
└── MessageRow.swift       # Individual message bubble
```

## Customization

- **Base URL**: Change `OllamaService.shared.baseURL` to point to a remote Ollama instance
- **System prompt**: Add a `.system` role message when creating a new `ChatSession`
- **Persistence**: Replace `UserDefaults` in `ChatStore` with CoreData or SQLite for larger history
# kairo-frontend
