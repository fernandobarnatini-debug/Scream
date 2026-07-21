import AppKit
import ApplicationServices
import CoreGraphics

/// Inserts transcribed text at the cursor of the frontmost app.
@MainActor
final class TextInserter {
    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func insert(_ text: String) async throws {
        switch settings.insertionStrategy {
        case .paste:
            try await insertViaPaste(text)
        case .accessibility:
            do {
                try insertViaAX(text)
            } catch {
                Log.insertion.warning("AX insertion failed, falling back to paste")
                try await insertViaPaste(text)
            }
        case .type:
            await insertViaTyping(text)
        }
    }

    // MARK: Paste (default)

    private func insertViaPaste(_ text: String) async throws {
        let pasteboard = NSPasteboard.general
        let snapshot = settings.restoreClipboard ? PasteboardGuard.snapshot() : nil

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        pasteboard.setString("", forType: PasteboardGuard.transientType)
        let ourChangeCount = pasteboard.changeCount

        // Give the target app's event loop room before the synthetic paste.
        try await Task.sleep(for: .milliseconds(60))
        postCmdV()

        if let snapshot {
            try await Task.sleep(for: .milliseconds(300))
            PasteboardGuard.restore(snapshot, ifChangeCountStill: ourChangeCount)
        }
    }

    private func postCmdV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    // MARK: Accessibility

    private func insertViaAX(_ text: String) throws {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        )
        guard result == .success, let focusedRef, CFGetTypeID(focusedRef) == AXUIElementGetTypeID() else {
            throw ScreamError.insertionFailed("no focused element")
        }
        let element = focusedRef as! AXUIElement
        let setResult = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFString
        )
        guard setResult == .success else {
            throw ScreamError.insertionFailed("AX error \(setResult.rawValue)")
        }
    }

    // MARK: Simulated typing

    private func insertViaTyping(_ text: String) async {
        let source = CGEventSource(stateID: .combinedSessionState)
        let units = Array(text.utf16)
        var index = 0
        while index < units.count {
            let chunk = Array(units[index..<min(index + 20, units.count)])
            if let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
               let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                chunk.withUnsafeBufferPointer { buffer in
                    down.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
                }
                down.post(tap: .cghidEventTap)
                up.post(tap: .cghidEventTap)
            }
            index += 20
            try? await Task.sleep(for: .milliseconds(8))
        }
    }
}
