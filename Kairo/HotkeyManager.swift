import AppKit
import Carbon

// MARK: - HotkeyManager
//
// Uses the Carbon RegisterEventHotKey API — the *only* macOS API that works
// reliably as a true system-wide hotkey, regardless of:
//   • Which app is frontmost
//   • Whether macOS has Ctrl+Space claimed for input-source switching
//   • Accessibility permission status
//
// NSEvent global monitors fire *after* the system has already processed the
// event, so they miss Ctrl+Space when macOS consumes it for input switching.
// RegisterEventHotKey fires *before* the system routes the event, winning the
// race every time.
//
// No Accessibility permission is required for this API.

/// Fired from the Carbon event handler — must be a free C-callable function.
private func carbonHotkeyHandler(
    _: EventHandlerCallRef?,
    _: EventRef?,
    userInfo: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userInfo else { return noErr }
    // Bridge back to the Swift manager and call the activate closure.
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
    DispatchQueue.main.async { manager.onActivate?() }
    return noErr
}

final class HotkeyManager {
    static let shared = HotkeyManager()

    /// Called on the main thread when Ctrl+Space fires.
    var onActivate: (() -> Void)?

    private var hotKeyRef:     EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private init() {}

    // MARK: - Public API

    /// Call once at app launch (from the main thread).
    func register() {
        // ── 1. Build the Carbon event type spec ────────────────────────────────
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind:  OSType(kEventHotKeyPressed)
        )

        // ── 2. Install the Carbon event handler ────────────────────────────────
        // Pass `self` as userInfo so the free-function handler can call back.
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            carbonHotkeyHandler,
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )

        // ── 3. Register the hotkey: Ctrl+Space ─────────────────────────────────
        //   kVK_Space = 49  (Carbon virtual key code, same as NSEvent keyCode)
        //   cmdKey / controlKey / etc. are Carbon modifier masks.
        //   controlKey = 0x1000 in Carbon.
        let hotkeyID = EventHotKeyID(signature: OSType(0x4B495254 /* "KIRT" */), id: 1)
        RegisterEventHotKey(
            UInt32(kVK_Space),      // virtual key: Space (49)
            UInt32(controlKey),     // modifier:    Control
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        print("[HotkeyManager] ✅ Ctrl+Space registered via Carbon RegisterEventHotKey")
    }

    func unregister() {
        if let h = hotKeyRef        { UnregisterEventHotKey(h); hotKeyRef = nil }
        if let h = eventHandlerRef  { RemoveEventHandler(h);    eventHandlerRef = nil }
    }
}
