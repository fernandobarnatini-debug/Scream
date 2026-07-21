import CoreGraphics
import Foundation
import Observation

/// "Record a shortcut" mode for the settings UI. Routes through the SAME
/// event tap as the runtime matcher, so it sees exactly the keycodes that
/// will be matched later — including fn and other modifier-only keys.
@MainActor
@Observable
final class KeyCaptureController {
    enum Target {
        case hold
        case toggle
    }

    private(set) var capturing: Target?
    private(set) var lastConflict: String?

    /// Called when capture ends for any reason; AppModel resets the hotkey
    /// engine's per-key state since it missed events during capture.
    var onFinished: (() -> Void)?

    private let eventTap: EventTapManager
    private let settings: SettingsStore
    private var pressedModifiers: Set<UInt16> = []

    init(eventTap: EventTapManager, settings: SettingsStore) {
        self.eventTap = eventTap
        self.settings = settings
    }

    func beginCapture(for target: Target) {
        lastConflict = nil
        pressedModifiers = []
        capturing = target
        eventTap.captureHandler = { [weak self] event in
            self?.handle(event) ?? false
        }
    }

    func endCapture() {
        capturing = nil
        pressedModifiers = []
        eventTap.captureHandler = nil
        onFinished?()
    }

    func clearBinding(for target: Target) {
        switch target {
        case .hold: settings.holdBinding = nil
        case .toggle: settings.toggleBinding = nil
        }
    }

    private func handle(_ event: EventTapManager.TapEvent) -> Bool {
        guard let target = capturing else { return false }
        switch event {
        case .keyDown(let keyCode, let flags, _):
            if keyCode == KeyCodes.escape {
                endCapture()
                return true
            }
            let binding = KeyBinding(
                keyCode: keyCode,
                modifiers: flags.intersection(KeyBinding.comparedFlags).rawValue,
                isModifierOnly: false
            )
            assign(binding, to: target)
            return true

        case .flagsChanged(let keyCode, _):
            // A lone modifier press-and-release becomes the binding; pressing
            // a normal key in between turns it into a combo (handled above).
            if pressedModifiers.contains(keyCode) {
                let binding = KeyBinding(keyCode: keyCode, modifiers: 0, isModifierOnly: true)
                assign(binding, to: target)
            } else {
                pressedModifiers.insert(keyCode)
            }
            return false

        case .keyUp:
            return true

        case .mouseDown(let button):
            // Extra mouse buttons only — the tap never delivers left/right
            // clicks, but guard anyway so ordinary clicking stays sacred.
            guard button >= 2 else { return false }
            let binding = KeyBinding(
                keyCode: UInt16(truncatingIfNeeded: button),
                modifiers: 0,
                isModifierOnly: false,
                source: .mouse
            )
            assign(binding, to: target)
            return true

        case .mouseUp(let button):
            return button >= 2
        }
    }

    private func assign(_ binding: KeyBinding, to target: Target) {
        let other = target == .hold ? settings.toggleBinding : settings.holdBinding
        if binding == other {
            lastConflict = "\(binding.displayString) is already the \(target == .hold ? "toggle" : "hold") key"
            endCapture()
            return
        }
        switch target {
        case .hold: settings.holdBinding = binding
        case .toggle: settings.toggleBinding = binding
        }
        endCapture()
    }
}
