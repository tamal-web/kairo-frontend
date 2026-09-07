# Kairo for macOS

Kairo is a native macOS AI assistant that deeply integrates with your operating system to understand your screen, files, documents, images, and context.

Instead of simply answering questions about text you provide, Kairo can understand what you're doing on your Mac and perform the extra work required to complete a task.

For example, ask:

> **"Summarize the document I'm reading."**

Kairo can understand what's on your screen, identify the document, locate the original file on your Mac, read the entire document, and generate a summary of the complete file — rather than only summarizing the text currently visible on screen.

Kairo is designed to feel less like a chatbot and more like an AI layer for your operating system.

## Features

### 🧠 Context-aware OS assistant

Kairo can understand the context of what you're doing on your Mac and use that context to perform tasks.

- Understand what's currently visible on your screen
- Use screen context to determine what you're working with
- Combine screen information with files and other OS data
- Take additional actions instead of simply returning an answer

### 📄 Intelligent document understanding

Kairo can go beyond the content currently visible on screen.

- Identify the document you're viewing
- Find the corresponding file on your Mac
- Read and process the complete document
- Summarize, analyze, or answer questions about the entire file
- Perform additional work based on the document's contents

### 🔎 Contextual file search

Kairo isn't just a filename search engine.

- Search files using natural language
- Search through file content and context
- Find documents based on what you're currently working on
- Locate relevant files automatically when completing tasks
- Connect information across multiple files

### 🖼️ Person & image understanding

Kairo can use images as part of its understanding of your files and screen.

- Find people through images
- Identify relevant photos based on visual context
- Search for information across image collections
- Use image understanding as part of larger tasks

### 📂 Automatic file organization

Kairo can help keep your Mac organized automatically.

- Organize files into appropriate folders
- Categorize documents based on their contents
- Group related files together
- Reduce manual file management

### 🔊 Natural text-to-speech

Kairo provides a better reading experience for on-screen content than the default macOS text-to-speech experience.

- Read what's currently on your screen
- Turn selected or visible content into speech
- Provide a more natural conversational voice
- Make long-form content easier to consume

### 💬 Local AI chat

Kairo supports locally running AI models through [Ollama](https://ollama.ai).

- Real-time streaming responses
- Chat history persisted locally
- Switch between locally installed models
- Automatically generate conversation titles
- Search previous conversations
- Copy AI responses
- Stop generation at any time

### ⚡ Native macOS experience

Built specifically for macOS using SwiftUI and designed to work naturally with the operating system.

- Native SwiftUI interface
- Keyboard shortcuts
- Persistent local state
- Deep OS integration
- Local-first AI processing through Ollama

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

# Pull a model in a new terminal
ollama pull llama3.2

# or
ollama pull mistral
ollama pull phi3
```

### 2. Open Kairo in Xcode

```bash
open Kairo.xcodeproj
```

Then press **⌘R** to build and run.

### 3. Grant required macOS permissions

Because Kairo integrates deeply with macOS, some features may require system permissions such as:

- Screen Recording
- Accessibility
- Files and Folders
- Microphone, where applicable

Enable the required permissions in:

**System Settings → Privacy & Security**

## Project Structure

```text
Kairo/
├── KairoApp.swift            # App entry point and commands
├── Models.swift              # Message, chat, AI and context models
├── OllamaService.swift       # Ollama streaming API client
├── ChatStore.swift           # Chat state and persistence
├── ContentView.swift         # Main application interface
├── SidebarView.swift         # Chat history and navigation
├── ChatView.swift            # Conversation interface
├── MessageRow.swift          # Individual message bubble
│
├── Context/                  # Screen and OS context
├── FileSearch/               # Natural-language file search
├── Documents/                # Document discovery and processing
├── Vision/                   # Image and person understanding
├── Organization/             # Automatic file organization
└── Speech/                   # Text-to-speech and screen reading
```

## Architecture

Kairo combines a local AI model with macOS system capabilities.

```text
                 ┌─────────────────────┐
                 │        Kairo        │
                 │   AI OS Assistant   │
                 └──────────┬──────────┘
                            │
          ┌─────────────────┼─────────────────┐
          │                 │                 │
          ▼                 ▼                 ▼
    Screen Context      File System       Vision
          │                 │                 │
          ▼                 ▼                 ▼
    Current App         Documents         Images
    Screen Content      Metadata          People
          │                 │                 │
          └─────────────────┼─────────────────┘
                            ▼
                    Local AI / Ollama
                            │
                            ▼
                    Action / Response
```

The goal is to let the AI reason across multiple sources of OS context and then perform useful actions rather than simply responding with text.

## Example

Instead of:

> "Here is the text from the PDF. Please summarize it."

You can ask:

> **"Summarize the document I'm looking at."**

Kairo can:

1. Understand what's currently on screen.
2. Determine which document you're viewing.
3. Locate the original file on your Mac.
4. Read the complete document.
5. Process the entire file with the AI.
6. Return a concise summary.

This same approach can be extended to searching, organizing files, understanding images, reading content aloud, and completing multi-step tasks.

## Customization

### Ollama endpoint

Change the Ollama base URL in `OllamaService` to connect to a different Ollama instance.

### Models

Kairo can use any compatible model available through your local Ollama installation.

```bash
ollama list
```

### Persistence

Chat history is currently stored locally. The persistence layer can be replaced with Core Data, SQLite, or another storage system as the application grows.

## Vision

Kairo's long-term goal is to become an AI interface for the operating system itself — one that understands not just what you ask, but what you're doing.

Rather than being another chatbot window, Kairo is built around **context → reasoning → action**.

# Kairo

An AI assistant that understands your Mac.
