import Carbon.HIToolbox

enum SecureInputDetector {
    /// True when a password field (or similar) has enabled secure event input —
    /// synthetic keyboard events are blocked there, so we refuse to record.
    static var isActive: Bool {
        IsSecureEventInputEnabled()
    }
}
