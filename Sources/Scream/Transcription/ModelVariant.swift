/// Curated subset of argmaxinc/whisperkit-coreml variants shown in the UI.
struct ModelVariant: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let sizeMB: Int
    let blurb: String

    static let catalog: [ModelVariant] = [
        ModelVariant(
            id: "openai_whisper-large-v3-v20240930_626MB",
            displayName: "Large v3 Turbo (compressed)",
            sizeMB: 626,
            blurb: "Best accuracy for dictation — recommended"
        ),
        ModelVariant(
            id: "distil-whisper_distil-large-v3_594MB",
            displayName: "Distil Large v3 (compressed)",
            sizeMB: 594,
            blurb: "Fastest large-class model, English-leaning"
        ),
        ModelVariant(
            id: "openai_whisper-small.en_217MB",
            displayName: "Small (English)",
            sizeMB: 217,
            blurb: "Low memory, English only"
        ),
        ModelVariant(
            id: "openai_whisper-tiny",
            displayName: "Tiny",
            sizeMB: 66,
            blurb: "Instant but rough — testing only"
        ),
    ]

    static func named(_ id: String) -> ModelVariant? {
        catalog.first { $0.id == id }
    }
}
