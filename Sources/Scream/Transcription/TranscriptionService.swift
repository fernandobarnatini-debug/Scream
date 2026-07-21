import Foundation
import WhisperKit

/// Owns the warm WhisperKit pipeline. Marked `@unchecked Sendable` because
/// WhisperKit itself is not Sendable; every caller goes through
/// DictationController / ModelManager, which serialize access.
final class TranscriptionService: @unchecked Sendable {
    static let modelsDirectory: URL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Scream/Models", isDirectory: true)

    private var whisperKit: WhisperKit?
    private(set) var loadedVariant: String?

    var isReady: Bool { whisperKit != nil }

    /// Loads (and ANE-specializes on first use) a downloaded model. Never
    /// touches the network: the model folder must already exist on disk.
    func loadModel(variant: String, modelFolder: URL) async throws {
        unload()
        let config = WhisperKitConfig(
            model: variant,
            downloadBase: Self.modelsDirectory,
            modelFolder: modelFolder.path,
            verbose: false,
            logLevel: .error,
            prewarm: true,
            load: true,
            download: false
        )
        whisperKit = try await WhisperKit(config)
        loadedVariant = variant
        Log.transcription.info("Model loaded: \(variant, privacy: .public)")
    }

    func unload() {
        whisperKit = nil
        loadedVariant = nil
    }

    func transcribe(_ samples: [Float], biasPrompt: String? = nil) async throws -> String {
        guard let whisperKit else { throw ScreamError.modelNotLoaded }
        guard samples.count >= Int(AudioRecorder.targetSampleRate / 4) else {
            throw ScreamError.recordingTooShort
        }

        var options = DecodingOptions(
            task: .transcribe,
            language: "en",
            usePrefillPrompt: true,
            skipSpecialTokens: true,
            withoutTimestamps: true,
            chunkingStrategy: .vad
        )
        if let biasPrompt, !biasPrompt.isEmpty, let tokenizer = whisperKit.tokenizer {
            let tokens = tokenizer.encode(text: " " + biasPrompt)
                .filter { $0 < tokenizer.specialTokens.specialTokenBegin }
            if !tokens.isEmpty {
                options.promptTokens = tokens
            }
        }

        let results = try await whisperKit.transcribe(audioArray: samples, decodeOptions: options)
        let text = results.map(\.text).joined(separator: " ")
        return Self.cleaned(text)
    }

    /// Strips Whisper's non-speech annotations like "[BLANK_AUDIO]" or "[Music]".
    private static func cleaned(_ text: String) -> String {
        text.replacing(/\[[^\]]*\]/, with: "")
            .replacing(/\s{2,}/, with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
