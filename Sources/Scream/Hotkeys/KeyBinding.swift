import CoreGraphics

/// A user-configurable trigger: a modifier-only key (fn, right ⌘, …) observed
/// via flagsChanged, a normal key plus required modifiers, or an extra mouse
/// button (middle/side — never left/right click).
struct KeyBinding: Codable, Equatable, Hashable, Sendable {
    enum Source: String, Codable, Sendable {
        case key
        case mouse
    }

    /// Virtual keycode, or the mouse button number for `.mouse` bindings.
    var keyCode: UInt16
    /// Required `CGEventFlags` (raw value) for normal-key bindings; 0 otherwise.
    var modifiers: UInt64
    var isModifierOnly: Bool
    var source: Source

    init(keyCode: UInt16, modifiers: UInt64, isModifierOnly: Bool, source: Source = .key) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.isModifierOnly = isModifierOnly
        self.source = source
    }

    // Custom decoding so bindings persisted before mouse support (no "source"
    // key) still load. Encoding stays synthesized.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keyCode = try container.decode(UInt16.self, forKey: .keyCode)
        modifiers = try container.decode(UInt64.self, forKey: .modifiers)
        isModifierOnly = try container.decode(Bool.self, forKey: .isModifierOnly)
        source = try container.decodeIfPresent(Source.self, forKey: .source) ?? .key
    }

    static let defaultHold = KeyBinding(keyCode: KeyCodes.fn, modifiers: 0, isModifierOnly: true)
    static let defaultToggle = KeyBinding(keyCode: KeyCodes.rightCommand, modifiers: 0, isModifierOnly: true)

    /// Only these flag bits participate in matching; ignore caps lock, fn side-effects, etc.
    static let comparedFlags: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]

    var displayString: String {
        switch source {
        case .mouse:
            // Button numbers are 0-based (0 left, 1 right, 2 middle, …).
            return "Mouse \(keyCode + 1)"
        case .key:
            if isModifierOnly {
                return KeyCodes.name(for: keyCode)
            }
            var parts = ""
            let flags = CGEventFlags(rawValue: modifiers)
            if flags.contains(.maskControl) { parts += "⌃" }
            if flags.contains(.maskAlternate) { parts += "⌥" }
            if flags.contains(.maskShift) { parts += "⇧" }
            if flags.contains(.maskCommand) { parts += "⌘" }
            return parts + KeyCodes.name(for: keyCode)
        }
    }

    func matchesKeyEvent(keyCode: UInt16, flags: CGEventFlags) -> Bool {
        guard source == .key, !isModifierOnly, keyCode == self.keyCode else { return false }
        let relevant = flags.intersection(Self.comparedFlags)
        return relevant == CGEventFlags(rawValue: modifiers).intersection(Self.comparedFlags)
    }

    func matchesMouseButton(_ button: Int64) -> Bool {
        source == .mouse && Int64(keyCode) == button
    }
}

enum KeyCodes {
    static let fn: UInt16 = 63
    static let rightCommand: UInt16 = 54
    static let leftCommand: UInt16 = 55
    static let leftShift: UInt16 = 56
    static let capsLock: UInt16 = 57
    static let leftOption: UInt16 = 58
    static let leftControl: UInt16 = 59
    static let rightShift: UInt16 = 60
    static let rightOption: UInt16 = 61
    static let rightControl: UInt16 = 62
    static let escape: UInt16 = 53

    static let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]

    /// Maps a modifier keycode to the CGEventFlags bit it drives.
    static func flag(forModifierKeyCode keyCode: UInt16) -> CGEventFlags? {
        switch keyCode {
        case 54, 55: .maskCommand
        case 56, 60: .maskShift
        case 57: .maskAlphaShift
        case 58, 61: .maskAlternate
        case 59, 62: .maskControl
        case 63: .maskSecondaryFn
        default: nil
        }
    }

    private static let names: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7",
        27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
        36: "↩", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
        45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space", 50: "`", 51: "⌫", 53: "⎋",
        54: "Right ⌘", 55: "⌘", 56: "⇧", 57: "⇪", 58: "⌥", 59: "⌃",
        60: "Right ⇧", 61: "Right ⌥", 62: "Right ⌃", 63: "fn",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11",
        105: "F13", 107: "F14", 109: "F10", 111: "F12", 113: "F15", 118: "F4",
        120: "F2", 122: "F1", 114: "Help", 115: "↖", 116: "⇞", 117: "⌦",
        119: "↘", 121: "⇟", 123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    static func name(for keyCode: UInt16) -> String {
        names[keyCode] ?? "Key \(keyCode)"
    }
}
