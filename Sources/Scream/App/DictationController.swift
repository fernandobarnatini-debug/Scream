import AppKit
import Foundation
import Observation

/// The orchestrator: hotkey commands in, inserted text out.
/// idle → recording → transcribing/postProcessing → inserting → idle
@MainActor
@Observable
final class DictationController {
    enum RecordingMode: Equatable {
        case hold
        case toggle
    }

    enum State: Equatable {
        case idle
        case recording(RecordingMode)
        case processing
    }

    private(set) var state: State = .idle

    private let settings: SettingsStore
    private let audio: AudioRecorder
    private let transcription: TranscriptionService
    private let inserter: TextInserter
    private let dictionary: DictionaryStore
    private let cleanup: CleanupService
    private let panel: RecordingPanelController

    private var targetApp: NSRunningApplication?
    private var idleTimer: Task<Void, Never>?

    init(
        settings: SettingsStore,
        audio: AudioRecorder,
        transcription: TranscriptionService,
        inserter: TextInserter,
        dictionary: DictionaryStore,
        cleanup: CleanupService,
        panel: RecordingPanelController
    ) {
        self.settings = settings
        self.audio = audio
        self.transcription = transcription
        self.inserter = inserter
        self.dictionary = dictionary
        self.cleanup = cleanup
        self.panel = panel
    }

    func handle(_ command: HotkeyEngine.Command) {
        switch command {
        case .beginHold:
            beginRecording(mode: .hold)
        case .beginToggle:
            beginRecording(mode: .toggle)
        case .endHold, .endToggle:
            finishRecording()
        case .cancelHold, .cancelActive:
            cancelRecording()
        }
    }

    private func beginRecording(mode: RecordingMode) {
        guard state == .idle else { return }
        guard transcription.isReady else {
            panel.showErrorAndHide("No speech model loaded yet")
            return
        }
        if SecureInputDetector.isActive {
            panel.showErrorAndHide("Secure field focused — dictation unavailable")
            return
        }

        idleTimer?.cancel()
        targetApp = NSWorkspace.shared.frontmostApplication

        do {
            try audio.startEngine()
        } catch {
            panel.showErrorAndHide(error.localizedDescription)
            return
        }
        audio.beginCapture()
        state = .recording(mode)
        panel.show(.recording)
        cleanup.prewarm()
        Log.app.info("Recording started (\(mode == .hold ? "hold" : "toggle", privacy: .public))")
    }

    private func finishRecording() {
        guard case .recording = state else { return }
        let samples = audio.endCapture()
        audio.levelMonitor.reset()
        state = .processing
        panel.update(.transcribing)
        scheduleEngineIdleStop()

        let targetBundleID = targetApp?.bundleIdentifier
        Task {
            do {
                var text = try await transcription.transcribe(samples, biasPrompt: dictionary.biasPrompt)
                if settings.voiceCommandsEnabled {
                    text = VoiceCommandProcessor.apply(to: text)
                }
                text = dictionary.apply(to: text)
                text = await cleanup.clean(text, targetBundleID: targetBundleID)

                guard !text.isEmpty else {
                    state = .idle
                    panel.showErrorAndHide("No speech detected")
                    return
                }
                try await inserter.insert(text)
                state = .idle
                panel.flashSuccessAndHide()
                Log.app.info("Inserted \(text.count, privacy: .public) characters")
            } catch {
                state = .idle
                panel.showErrorAndHide(error.localizedDescription)
                Log.app.error("Dictation failed: \(error.localizedDescription)")
            }
        }
    }

    private func cancelRecording() {
        guard case .recording = state else { return }
        audio.cancelCapture()
        audio.levelMonitor.reset()
        state = .idle
        panel.hide()
        scheduleEngineIdleStop()
        Log.app.info("Recording cancelled")
    }

    /// Stops the audio engine (and clears the mic indicator) after a quiet
    /// period; kept warm between utterances for instant starts.
    private func scheduleEngineIdleStop() {
        idleTimer?.cancel()
        let timeout = settings.micIdleTimeout
        idleTimer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(timeout))
            guard !Task.isCancelled, let self, self.state == .idle else { return }
            self.audio.stopEngine()
        }
    }
}
