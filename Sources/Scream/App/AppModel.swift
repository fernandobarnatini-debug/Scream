import Foundation
import Observation

/// Root object graph, owned by the AppDelegate and injected into every scene.
@MainActor
@Observable
final class AppModel {
    let settings: SettingsStore
    let permissions = PermissionsModel()
    let audio = AudioRecorder()
    let transcription = TranscriptionService()
    let modelManager: ModelManager
    let dictionary = DictionaryStore()
    let cleanup: CleanupService
    let inserter: TextInserter
    let panel: RecordingPanelController
    let dictation: DictationController
    let eventTap = EventTapManager()
    let hotkeys: HotkeyEngine
    let keyCapture: KeyCaptureController

    var lastTestTranscript: String?

    init() {
        let settings = SettingsStore()
        self.settings = settings
        self.modelManager = ModelManager(transcription: transcription, settings: settings)
        self.cleanup = CleanupService(settings: settings)
        self.inserter = TextInserter(settings: settings)
        self.panel = RecordingPanelController(levelMonitor: audio.levelMonitor)
        self.dictation = DictationController(
            settings: settings,
            audio: audio,
            transcription: transcription,
            inserter: inserter,
            dictionary: dictionary,
            cleanup: cleanup,
            panel: panel
        )
        self.hotkeys = HotkeyEngine(settings: settings)
        self.keyCapture = KeyCaptureController(eventTap: eventTap, settings: settings)

        keyCapture.onFinished = { [weak self] in
            self?.hotkeys.reset()
        }
        hotkeys.onCommand = { [weak self] command in
            self?.dictation.handle(command)
        }
        eventTap.handler = { [weak self] event in
            self?.hotkeys.handle(event) ?? false
        }
        eventTap.onReenabled = { [weak self] in
            self?.hotkeys.reset()
        }
    }

    func bootstrap() {
        permissions.refresh()
        Task {
            await modelManager.activateSelectedIfDownloaded()
        }
        startHotkeysWhenTrusted()
    }

    /// The event tap can only be created once Accessibility is granted; poll
    /// until then (covers first-run onboarding and revoked-then-restored).
    private func startHotkeysWhenTrusted() {
        Task { [weak self] in
            while let self, !self.eventTap.isRunning {
                self.permissions.refresh()
                if self.permissions.accessibility, self.eventTap.start() {
                    break
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    /// Debug harness used from the menu bar: records five seconds and logs +
    /// surfaces the transcript.
    func runFiveSecondTest() async {
        do {
            try audio.startEngine()
            audio.beginCapture()
            try await Task.sleep(for: .seconds(5))
            let samples = audio.endCapture()
            lastTestTranscript = "Transcribing…"
            let text = try await transcription.transcribe(samples)
            lastTestTranscript = text.isEmpty ? "(no speech detected)" : text
            Log.transcription.info("Test transcript: \(text, privacy: .public)")
        } catch {
            lastTestTranscript = "Error: \(error.localizedDescription)"
            Log.transcription.error("Test failed: \(error.localizedDescription)")
        }
    }
}
