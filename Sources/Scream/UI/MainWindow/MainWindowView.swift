import SwiftUI

/// Content of the app's main window: a status header above the settings tabs.
struct MainWindowView: View {
    @Bindable var model: AppModel
    var showOnboarding: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            SettingsView(model: model)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Scream")
                    .font(.title3.weight(.semibold))
                Text(model.modelManager.statusDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Set Up…") {
                showOnboarding()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
