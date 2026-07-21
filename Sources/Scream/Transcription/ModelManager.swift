import Foundation
import Observation
import WhisperKit

@MainActor
@Observable
final class ModelManager {
    enum Phase: Equatable {
        case idle
        case downloading(variant: String, progress: Double)
        case loading(variant: String)
        case ready(variant: String)
        case failed(variant: String, message: String)
    }

    private(set) var phase: Phase = .idle
    private(set) var downloadedVariants: Set<String> = []

    private let transcription: TranscriptionService
    private let settings: SettingsStore

    init(transcription: TranscriptionService, settings: SettingsStore) {
        self.transcription = transcription
        self.settings = settings
        refreshDownloaded()
    }

    var activeVariant: String? {
        if case .ready(let variant) = phase { variant } else { nil }
    }

    var isBusy: Bool {
        switch phase {
        case .downloading, .loading: true
        default: false
        }
    }

    var statusDescription: String {
        switch phase {
        case .idle:
            "No model loaded"
        case .downloading(let variant, let progress):
            "Downloading \(shortName(variant)) — \(Int(progress * 100))%"
        case .loading(let variant):
            "Optimizing \(shortName(variant)) for this Mac…"
        case .ready(let variant):
            "Model: \(shortName(variant))"
        case .failed(_, let message):
            "Model error: \(message)"
        }
    }

    private var repoDirectory: URL {
        TranscriptionService.modelsDirectory
            .appendingPathComponent("models/argmaxinc/whisperkit-coreml", isDirectory: true)
    }

    func folder(for variant: String) -> URL {
        repoDirectory.appendingPathComponent(variant, isDirectory: true)
    }

    func isDownloaded(_ variant: String) -> Bool {
        downloadedVariants.contains(variant)
    }

    func refreshDownloaded() {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: repoDirectory,
            includingPropertiesForKeys: [.isDirectoryKey]
        )) ?? []
        downloadedVariants = Set(contents.filter(\.hasDirectoryPath).map(\.lastPathComponent))
    }

    /// Downloads the variant if needed (with progress), then loads it as the
    /// active transcription model.
    func activate(_ variant: String) async {
        guard !isBusy else { return }
        do {
            if !isDownloaded(variant) {
                phase = .downloading(variant: variant, progress: 0)
                _ = try await WhisperKit.download(
                    variant: variant,
                    downloadBase: TranscriptionService.modelsDirectory,
                    progressCallback: { [weak self] progress in
                        let fraction = progress.fractionCompleted
                        Task { @MainActor in
                            self?.phase = .downloading(variant: variant, progress: fraction)
                        }
                    }
                )
                refreshDownloaded()
            }
            phase = .loading(variant: variant)
            try await transcription.loadModel(variant: variant, modelFolder: folder(for: variant))
            settings.selectedModel = variant
            phase = .ready(variant: variant)
        } catch {
            Log.transcription.error("Model activation failed: \(error.localizedDescription)")
            phase = .failed(variant: variant, message: error.localizedDescription)
        }
    }

    func activateSelectedIfDownloaded() async {
        let variant = settings.selectedModel
        guard isDownloaded(variant) else { return }
        await activate(variant)
    }

    func delete(_ variant: String) {
        if activeVariant == variant || transcription.loadedVariant == variant {
            transcription.unload()
            phase = .idle
        }
        try? FileManager.default.removeItem(at: folder(for: variant))
        refreshDownloaded()
    }

    func diskUsage(of variant: String) -> Int64 {
        guard let files = FileManager.default.enumerator(
            at: folder(for: variant),
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in files {
            total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }

    private func shortName(_ variant: String) -> String {
        ModelVariant.named(variant)?.displayName ?? variant
    }
}
