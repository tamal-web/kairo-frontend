// AssistantPanelManager.swift
import AppKit
import SwiftUI

// MARK: - KairoFloatingPanel

/// NSPanel subclass that can become the key window even when created with
/// .nonactivatingPanel — necessary for TextField to receive keyboard events.
final class KairoFloatingPanel: NSPanel {
    override var canBecomeKey: Bool  { true }
    override var canBecomeMain: Bool { false }

    // ── Critical fix ──────────────────────────────────────────────────────────
    // Returning true here tells AppKit this window has no opaque content of its
    // own. Combined with a clear backgroundColor, AppKit will NOT composite a
    // solid window-background layer behind your SwiftUI content, which is the
    // source of the black halo that bleeds past rounded corners.
    override var isOpaque: Bool {
        get { false }
        set { }   // ignore any framework attempts to set it back
    }
}

// MARK: - ViewModel

@MainActor
final class AssistantViewModel: ObservableObject {

    enum Phase: Equatable {
        case idle
        case asking
        case responding
        case done
    }

    @Published var inputText: String     = ""
    @Published var phase: Phase          = .idle
    @Published var submittedText: String = ""
    @Published var focusTrigger: Int     = 0

    func reset() {
        inputText     = ""
        phase         = .idle
        submittedText = ""
    }
}

// MARK: - Panel Manager

@MainActor
final class AssistantPanelManager: ObservableObject {
    static let shared = AssistantPanelManager()

    let viewModel = AssistantViewModel()

    private var panel:               NSPanel?
    private var outsideClickMonitor: Any?

    private init() {}

    // MARK: - Setup

    func setup(store: ChatStore) {
        HotkeyManager.shared.onActivate = { [weak self] in
            Task { @MainActor [weak self] in self?.toggle(store: store) }
        }
        HotkeyManager.shared.register()
    }

    // MARK: - Toggle / Show / Hide

    func toggle(store: ChatStore) {
        if panel?.isVisible == true { 
            hide() 
        } else { 
            takeScreenshot()
            show(store: store) 
        }
    }

    private func takeScreenshot() {
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-x", "-C", "/tmp/kairo_screenshot.png"]
        
        do {
            try task.run()
            task.waitUntilExit()
            print("[AssistantPanelManager] Screenshot saved to /tmp/kairo_screenshot.png")
        } catch {
            print("[AssistantPanelManager] Failed to take screenshot: \(error)")
        }
    }

    private func show(store: ChatStore) {
        viewModel.reset()
        if panel == nil { buildPanel(store: store) }
        guard let panel else { return }

        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size   = panelSize(for: .idle)
        panel.setFrame(
            NSRect(x: screen.midX - size.width / 2,
                   y: screen.maxY - size.height - 80,
                   width: size.width, height: size.height),
            display: false
        )

        panel.orderFrontRegardless()
        panel.makeKey()

        startOutsideClickMonitor()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.viewModel.focusTrigger += 1
        }
    }

    func hide() {
        panel?.orderOut(nil)
        stopOutsideClickMonitor()
    }

    // MARK: - Animated resize

    func resizePanel(to phase: AssistantViewModel.Phase, animated: Bool = true) {
        guard let panel else { return }
        let newSize  = panelSize(for: phase)
        let cur      = panel.frame
        let newFrame = NSRect(
            x:      cur.midX - newSize.width / 2,
            y:      cur.maxY - newSize.height,
            width:  newSize.width,
            height: newSize.height
        )
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration       = 0.28
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(newFrame, display: true)
            }
        } else {
            panel.setFrame(newFrame, display: true)
        }
    }

    private func panelSize(for phase: AssistantViewModel.Phase) -> NSSize {
        switch phase {
        case .idle:                         return NSSize(width: 660, height: 68)
        case .asking, .responding, .done:   return NSSize(width: 660, height: 480)
        }
    }

    // MARK: - Build Panel

    private func buildPanel(store: ChatStore) {
        let p = KairoFloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 68),
            styleMask:   [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing:     .buffered,
            defer:       true
        )

        p.level              = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue)
        p.backgroundColor    = .clear

        // ── Do NOT set hasShadow = true on the NSPanel itself ─────────────────
        // AppKit's built-in window shadow is drawn against the window's opaque
        // backing store. On a borderless + clear panel it projects from the
        // rectangular window frame (not the SwiftUI rounded rect), producing the
        // black halo. Shadow is instead handled entirely by SwiftUI via
        // .shadow() modifiers on the rounded-rect background in AssistantView,
        // which correctly clips to the visual shape.
        p.hasShadow          = false

        p.hidesOnDeactivate  = false
        p.isMovableByWindowBackground = true
        p.isFloatingPanel    = true
        p.becomesKeyOnlyIfNeeded = false

        var cb = NSWindow.CollectionBehavior()
        cb.insert(.canJoinAllSpaces)
        cb.insert(.fullScreenAuxiliary)
        cb.insert(.ignoresCycle)
        cb.insert(.stationary)
        p.collectionBehavior = cb

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak p] event in
            guard let panel = p, panel.isKeyWindow, event.keyCode == 53 else { return event }
            Task { @MainActor in AssistantPanelManager.shared.hide() }
            return nil
        }

        let rootView = AssistantView(manager: self, viewModel: viewModel)
            .environmentObject(store)

        let hc = NSHostingController(rootView: rootView)

        // ── Fully transparent hosting view ────────────────────────────────────
        // NSHostingController adds its own CALayer-backed NSView. Without these
        // lines the layer renders with a default opaque black background that
        // bleeds outside the SwiftUI rounded corners as a dark border / halo.
        hc.view.wantsLayer             = true
        hc.view.layer?.backgroundColor = .clear
        hc.view.layer?.isOpaque        = false   // ← extra flag AppKit checks

        // ── Remove the default window chrome background ───────────────────────
        // contentView is a private NSVisualEffectView or plain NSView that AppKit
        // inserts automatically. Making it transparent prevents a second opaque
        // backdrop from appearing behind the hosting controller.
        if let contentView = p.contentView {
            contentView.wantsLayer             = true
            contentView.layer?.backgroundColor = .clear
            contentView.layer?.isOpaque        = false
        }

        p.contentViewController = hc
        self.panel = p
    }

    // MARK: - Outside-click detection

    private func startOutsideClickMonitor() {
        stopOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self, let panel = self.panel, panel.isVisible else { return }
            if !panel.frame.contains(NSEvent.mouseLocation) {
                Task { @MainActor in self.hide() }
            }
        }
    }

    private func stopOutsideClickMonitor() {
        if let m = outsideClickMonitor { NSEvent.removeMonitor(m); outsideClickMonitor = nil }
    }
}
