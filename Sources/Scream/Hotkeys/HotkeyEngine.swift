import CoreGraphics
import Foundation

/// Turns raw tap events into dictation commands, implementing hold-to-talk,
/// press-to-toggle, chord-abort, and Esc-to-cancel semantics.
@MainActor
final class HotkeyEngine {
    enum Command {
        case beginHold
        case endHold
        case cancelHold
        case beginToggle
        case endToggle
        case cancelActive
    }

    private enum Mode {
        case hold
        case toggle
    }

    var onCommand: ((Command) -> Void)?

    private let settings: SettingsStore
    /// Physical modifier keys currently held, by keycode (flagsChanged has no
    /// explicit down/up, so presence toggles per event).
    private var pressedModifiers: Set<UInt16> = []
    private var holdKeyDown = false
    private var holdContaminated = false
    private var holdStart: ContinuousClock.Instant?
    private var mode: Mode?

    /// Releases shorter than this are treated as accidental taps of the hold key.
    private static let minimumHoldDuration: Duration = .milliseconds(250)

    init(settings: SettingsStore) {
        self.settings = settings
    }

    /// Called when the tap was re-enabled after a system disable — assume we
    /// missed events and drop all per-key state.
    func reset() {
        pressedModifiers.removeAll()
        holdKeyDown = false
        holdContaminated = false
        holdStart = nil
        if mode != nil {
            mode = nil
            onCommand?(.cancelActive)
        }
    }

    /// Returns true to consume the event.
    func handle(_ event: EventTapManager.TapEvent) -> Bool {
        switch event {
        case .flagsChanged(let keyCode, _):
            let wasPressed = pressedModifiers.contains(keyCode)
            if wasPressed {
                pressedModifiers.remove(keyCode)
            } else {
                pressedModifiers.insert(keyCode)
            }
            let isDown = !wasPressed

            if let hold = settings.holdBinding, hold.isModifierOnly, hold.keyCode == keyCode {
                holdKeyEvent(isDown: isDown)
            } else if let toggle = settings.toggleBinding, toggle.isModifierOnly,
                      toggle.keyCode == keyCode, isDown {
                toggleKeyPressed()
            }
            // Never consume flagsChanged — harmless, and other apps need them.
            return false

        case .keyDown(let keyCode, let flags, let isRepeat):
            if keyCode == KeyCodes.escape, mode != nil {
                mode = nil
                onCommand?(.cancelActive)
                return true
            }

            // Chord-abort: the user pressed another key while holding a
            // modifier-only hold binding — that's Cmd+C, not dictation.
            if holdKeyDown, settings.holdBinding?.isModifierOnly == true {
                holdContaminated = true
                if mode == .hold {
                    mode = nil
                    onCommand?(.cancelHold)
                }
                return false
            }

            if let hold = settings.holdBinding, hold.matchesKeyEvent(keyCode: keyCode, flags: flags) {
                if !isRepeat {
                    holdKeyEvent(isDown: true)
                }
                return true
            }
            if let toggle = settings.toggleBinding, toggle.matchesKeyEvent(keyCode: keyCode, flags: flags) {
                if !isRepeat {
                    toggleKeyPressed()
                }
                return true
            }
            return false

        case .keyUp(let keyCode, _):
            if let hold = settings.holdBinding, hold.source == .key, !hold.isModifierOnly,
               hold.keyCode == keyCode, holdKeyDown {
                holdKeyEvent(isDown: false)
                return true
            }
            if let toggle = settings.toggleBinding, toggle.source == .key, !toggle.isModifierOnly,
               toggle.keyCode == keyCode {
                return true
            }
            return false

        case .mouseDown(let button):
            if let hold = settings.holdBinding, hold.matchesMouseButton(button) {
                holdKeyEvent(isDown: true)
                return true
            }
            if let toggle = settings.toggleBinding, toggle.matchesMouseButton(button) {
                toggleKeyPressed()
                return true
            }
            return false

        case .mouseUp(let button):
            if let hold = settings.holdBinding, hold.matchesMouseButton(button), holdKeyDown {
                holdKeyEvent(isDown: false)
                return true
            }
            // Consume the matching up of a toggle click we consumed the down for.
            if let toggle = settings.toggleBinding, toggle.matchesMouseButton(button) {
                return true
            }
            return false
        }
    }

    private func holdKeyEvent(isDown: Bool) {
        if isDown {
            holdKeyDown = true
            holdContaminated = false
            holdStart = .now
            guard mode == nil else { return }
            mode = .hold
            onCommand?(.beginHold)
        } else {
            holdKeyDown = false
            guard mode == .hold else { return }
            mode = nil
            let duration = holdStart.map { ContinuousClock.Instant.now - $0 } ?? .zero
            if holdContaminated || duration < Self.minimumHoldDuration {
                onCommand?(.cancelHold)
            } else {
                onCommand?(.endHold)
            }
        }
    }

    private func toggleKeyPressed() {
        switch mode {
        case nil:
            mode = .toggle
            onCommand?(.beginToggle)
        case .toggle:
            mode = nil
            onCommand?(.endToggle)
        case .hold:
            break
        }
    }
}
