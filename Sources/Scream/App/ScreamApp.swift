import SwiftUI

@main
struct ScreamApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Scream", systemImage: "waveform") {
            MenuBarContent(
                model: appDelegate.model,
                showOnboarding: appDelegate.showOnboarding,
                showMainWindow: appDelegate.showMainWindow
            )
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    appDelegate.showMainWindow()
                }
                .keyboardShortcut(",")
            }
        }
    }
}

private struct MenuBarContent: View {
    @Bindable var model: AppModel
    var showOnboarding: () -> Void
    var showMainWindow: () -> Void

    var body: some View {
        Text(model.modelManager.statusDescription)

        if let transcript = model.lastTestTranscript {
            Text(transcript)
        }

        Divider()

        Button("Test: Record 5 s → Transcribe") {
            Task { await model.runFiveSecondTest() }
        }
        .disabled(model.modelManager.activeVariant == nil)

        Button("Setup…") {
            showOnboarding()
        }

        Button("Settings…") {
            showMainWindow()
        }
        .keyboardShortcut(",")

        Divider()

        Button("Quit Scream") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
