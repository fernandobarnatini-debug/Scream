import Foundation
import Observation

enum InsertionStrategy: String, Codable, CaseIterable, Sendable {
    case paste
    case accessibility
    case type

    var label: String {
        switch self {
        case .paste: "Paste (recommended)"
        case .accessibility: "Accessibility API"
        case .type: "Simulated typing"
        }
    }
}

@MainActor
@Observable
final class SettingsStore {
    static let defaultModel = "openai_whisper-large-v3-v20240930_626MB"

    var holdBinding: KeyBinding? {
        didSet { Self.writeJSON(holdBinding, key: "holdBinding") }
    }
    var toggleBinding: KeyBinding? {
        didSet { Self.writeJSON(toggleBinding, key: "toggleBinding") }
    }
    var selectedModel: String {
        didSet { Self.defaults.set(selectedModel, forKey: "selectedModel") }
    }
    var insertionStrategy: InsertionStrategy {
        didSet { Self.defaults.set(insertionStrategy.rawValue, forKey: "insertionStrategy") }
    }
    var restoreClipboard: Bool {
        didSet { Self.defaults.set(restoreClipboard, forKey: "restoreClipboard") }
    }
    var voiceCommandsEnabled: Bool {
        didSet { Self.defaults.set(voiceCommandsEnabled, forKey: "voiceCommandsEnabled") }
    }
    var cleanupEnabled: Bool {
        didSet { Self.defaults.set(cleanupEnabled, forKey: "cleanupEnabled") }
    }
    var ollamaModel: String {
        didSet { Self.defaults.set(ollamaModel, forKey: "ollamaModel") }
    }
    var launchAtLogin: Bool {
        didSet { LaunchAtLogin.set(enabled: launchAtLogin) }
    }
    var hasCompletedOnboarding: Bool {
        didSet { Self.defaults.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }
    var micIdleTimeout: Double {
        didSet { Self.defaults.set(micIdleTimeout, forKey: "micIdleTimeout") }
    }

    private static let defaults = UserDefaults.standard

    init() {
        let d = Self.defaults
        holdBinding = Self.readJSON(KeyBinding.self, key: "holdBinding", registered: .defaultHold)
        toggleBinding = Self.readJSON(KeyBinding.self, key: "toggleBinding", registered: .defaultToggle)
        selectedModel = d.string(forKey: "selectedModel") ?? Self.defaultModel
        insertionStrategy = d.string(forKey: "insertionStrategy").flatMap(InsertionStrategy.init) ?? .paste
        restoreClipboard = d.object(forKey: "restoreClipboard") as? Bool ?? true
        voiceCommandsEnabled = d.object(forKey: "voiceCommandsEnabled") as? Bool ?? true
        cleanupEnabled = d.object(forKey: "cleanupEnabled") as? Bool ?? false
        ollamaModel = d.string(forKey: "ollamaModel") ?? "llama3.2:3b"
        launchAtLogin = LaunchAtLogin.isEnabled
        hasCompletedOnboarding = d.bool(forKey: "hasCompletedOnboarding")
        micIdleTimeout = d.object(forKey: "micIdleTimeout") as? Double ?? 30
    }

    // A binding the user explicitly cleared is stored as empty data, distinct from never-set.
    private static func readJSON<T: Decodable>(_ type: T.Type, key: String, registered: T?) -> T? {
        guard let data = defaults.data(forKey: key) else { return registered }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func writeJSON(_ value: (some Encodable)?, key: String) {
        if let value, let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        } else {
            defaults.set(Data(), forKey: key)
        }
    }
}
