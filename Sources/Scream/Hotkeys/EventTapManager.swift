import AppKit
import CoreGraphics

/// Owns the single active CGEventTap. An *active* (consuming) keyboard tap is
/// gated on the Accessibility permission, which also covers posting the
/// synthetic Cmd+V used for insertion — one permission serves both.
///
/// The C callback runs on the main run loop (the tap's source is added there),
/// so `MainActor.assumeIsolated` in the trampoline is sound.
@MainActor
final class EventTapManager {
    enum TapEvent {
        case keyDown(keyCode: UInt16, flags: CGEventFlags, isRepeat: Bool)
        case keyUp(keyCode: UInt16, flags: CGEventFlags)
        case flagsChanged(keyCode: UInt16, flags: CGEventFlags)
        /// Extra mouse buttons only (middle/side); left/right never arrive here.
        case mouseDown(button: Int64)
        case mouseUp(button: Int64)
    }

    /// Returns true to consume the event. Checked before `handler` so the
    /// settings key-recorder sees exactly what the runtime matcher would.
    var captureHandler: ((TapEvent) -> Bool)?
    var handler: ((TapEvent) -> Bool)?
    /// Fired when the system disabled the tap (timeout/user input) and we
    /// re-enabled it — listeners should reset any per-key state.
    var onReenabled: (() -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var isRunning: Bool { tap != nil }

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapTrampoline,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Log.hotkeys.error("Event tap creation failed — Accessibility not granted?")
            return false
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        Log.hotkeys.info("Event tap started")
        return true
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        runLoopSource = nil
        tap = nil
    }

    fileprivate func reenableTap() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
        Log.hotkeys.warning("Event tap was disabled by the system — re-enabled")
        onReenabled?()
    }

    /// Returns true to consume the event.
    fileprivate func dispatch(_ event: TapEvent) -> Bool {
        if let captureHandler {
            return captureHandler(event)
        }
        return handler?(event) ?? false
    }
}

private func eventTapTrampoline(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()

    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        MainActor.assumeIsolated {
            manager.reenableTap()
        }
        return Unmanaged.passUnretained(event)

    case .keyDown, .keyUp, .flagsChanged:
        // Extract Sendable scalars before hopping — CGEvent itself must not
        // cross into the isolated closure.
        let keyCode = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        let tapEvent: EventTapManager.TapEvent = switch type {
        case .keyDown:
            .keyDown(
                keyCode: keyCode,
                flags: flags,
                isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            )
        case .keyUp:
            .keyUp(keyCode: keyCode, flags: flags)
        default:
            .flagsChanged(keyCode: keyCode, flags: flags)
        }
        let consume = MainActor.assumeIsolated {
            manager.dispatch(tapEvent)
        }
        return consume ? nil : Unmanaged.passUnretained(event)

    case .otherMouseDown, .otherMouseUp:
        let button = event.getIntegerValueField(.mouseEventButtonNumber)
        let tapEvent: EventTapManager.TapEvent = type == .otherMouseDown
            ? .mouseDown(button: button)
            : .mouseUp(button: button)
        let consume = MainActor.assumeIsolated {
            manager.dispatch(tapEvent)
        }
        return consume ? nil : Unmanaged.passUnretained(event)

    default:
        return Unmanaged.passUnretained(event)
    }
}
