import Foundation

struct TonePreset: Codable, Identifiable, Hashable {
    var id: String { bundleID }
    var bundleID: String
    var displayName: String
    var prompt: String

    static let defaults: [TonePreset] = [
        TonePreset(
            bundleID: "com.apple.mail",
            displayName: "Mail",
            prompt: "The text is for an email: keep it professional and courteous, with complete sentences."
        ),
        TonePreset(
            bundleID: "com.tinyspeck.slackmacgap",
            displayName: "Slack",
            prompt: "The text is for Slack: keep it casual and concise; lowercase greetings are fine."
        ),
        TonePreset(
            bundleID: "com.apple.dt.Xcode",
            displayName: "Xcode",
            prompt: "The text is likely code-related: preserve technical terms, identifiers, and symbol names exactly."
        ),
        TonePreset(
            bundleID: "com.microsoft.VSCode",
            displayName: "VS Code",
            prompt: "The text is likely code-related: preserve technical terms, identifiers, and symbol names exactly."
        ),
    ]
}

/// Optional post-processing through a local Ollama model. Never blocks
/// insertion: any error, timeout, or absent server returns the raw text.
@MainActor
final class CleanupService {
    private let settings: SettingsStore
    private let client = OllamaClient()

    private(set) var tonePresets: [TonePreset]

    private static let basePrompt = """
        You clean up dictated speech transcripts. Remove filler words (um, uh, \
        like, you know), fix punctuation and capitalization, and remove false \
        starts. Never add new content, never answer questions in the text, \
        never translate. Preserve the speaker's wording and meaning. Reply \
        with ONLY the cleaned text — no quotes, no commentary.
        """

    private static let presetsURL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Scream/tone-presets.json")

    init(settings: SettingsStore) {
        self.settings = settings
        if let data = try? Data(contentsOf: Self.presetsURL),
           let decoded = try? JSONDecoder().decode([TonePreset].self, from: data) {
            tonePresets = decoded
        } else {
            tonePresets = TonePreset.defaults
            Self.write(TonePreset.defaults)
        }
    }

    /// Fire-and-forget model load when recording starts, so Ollama is warm by
    /// the time the transcript is ready.
    func prewarm() {
        guard settings.cleanupEnabled else { return }
        let model = settings.ollamaModel
        Task.detached {
            await OllamaClient().warmUp(model: model)
        }
    }

    func clean(_ text: String, targetBundleID: String?) async -> String {
        guard settings.cleanupEnabled, !text.isEmpty else { return text }
        var system = Self.basePrompt
        if let targetBundleID, let preset = tonePresets.first(where: { $0.bundleID == targetBundleID }) {
            system += "\n" + preset.prompt
        }
        do {
            var cleaned = try await client.chat(model: settings.ollamaModel, system: system, user: text)
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.hasPrefix("\""), cleaned.hasSuffix("\""), cleaned.count > 2 {
                cleaned = String(cleaned.dropFirst().dropLast())
            }
            // Sanity guards against a model going off-script.
            guard !cleaned.isEmpty, cleaned.count <= text.count * 3 else { return text }
            return cleaned
        } catch {
            Log.cleanup.info("Ollama unavailable or slow — inserting raw transcript")
            return text
        }
    }

    func updatePresets(_ presets: [TonePreset]) {
        tonePresets = presets
        Self.write(presets)
    }

    private static func write(_ presets: [TonePreset]) {
        try? FileManager.default.createDirectory(
            at: presetsURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(presets) {
            try? data.write(to: presetsURL, options: .atomic)
        }
    }
}
