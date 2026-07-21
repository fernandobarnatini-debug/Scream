import SwiftUI

struct OnboardingView: View {
    @Bindable var model: AppModel
    var onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome to Scream")
                    .font(.title.bold())
                Text("Local dictation — your voice never leaves this Mac.")
                    .foregroundStyle(.secondary)
            }

            permissionRow(
                title: "Microphone",
                detail: "Needed to hear you while dictating.",
                granted: model.permissions.microphone == .granted
            ) {
                Task { await model.permissions.requestMicrophone() }
            }

            permissionRow(
                title: "Accessibility",
                detail: "Needed for the dictation hotkey and to type text into other apps.",
                granted: model.permissions.accessibility
            ) {
                model.permissions.requestAccessibility()
            }

            modelRow

            Divider()

            HStack {
                Spacer()
                Button("Start Dictating") {
                    model.settings.hasCompletedOnboarding = true
                    onDone()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!setupComplete)
            }
        }
        .padding(28)
        .frame(width: 460)
        .onAppear {
            model.permissions.refresh()
            model.permissions.startPolling()
        }
        .onDisappear {
            model.permissions.stopPolling()
        }
    }

    private var setupComplete: Bool {
        model.permissions.allGranted && model.modelManager.activeVariant != nil
    }

    private var modelRow: some View {
        HStack(alignment: .top, spacing: 12) {
            statusDot(on: model.modelManager.activeVariant != nil)
            VStack(alignment: .leading, spacing: 2) {
                Text("Speech model")
                    .font(.headline)
                Text(modelDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if case .downloading(_, let progress) = model.modelManager.phase {
                    ProgressView(value: progress)
                        .frame(width: 220)
                } else if case .loading = model.modelManager.phase {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            Spacer()
            if model.modelManager.activeVariant == nil, !model.modelManager.isBusy {
                Button("Download") {
                    Task { await model.modelManager.activate(model.settings.selectedModel) }
                }
            }
        }
    }

    private var modelDetail: String {
        switch model.modelManager.phase {
        case .idle:
            let variant = ModelVariant.named(model.settings.selectedModel)
            return "\(variant?.displayName ?? model.settings.selectedModel) (\(variant?.sizeMB ?? 0) MB) — one-time download, then fully offline."
        case .loading:
            return "Optimizing for Apple Neural Engine — one time, takes a minute or two."
        default:
            return model.modelManager.statusDescription
        }
    }

    private func permissionRow(
        title: String,
        detail: String,
        granted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            statusDot(on: granted)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !granted {
                Button("Grant") { action() }
            }
        }
    }

    private func statusDot(on: Bool) -> some View {
        Circle()
            .fill(on ? Color.green : Color.secondary.opacity(0.4))
            .frame(width: 10, height: 10)
            .padding(.top, 5)
    }
}
