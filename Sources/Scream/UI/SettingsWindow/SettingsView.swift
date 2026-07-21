import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        TabView {
            GeneralTab(model: model)
                .tabItem { Label("General", systemImage: "gearshape") }
            KeysTab(model: model)
                .tabItem { Label("Keys", systemImage: "keyboard") }
            ModelsTab(model: model)
                .tabItem { Label("Model", systemImage: "cpu") }
            DictionaryTab(model: model)
                .tabItem { Label("Dictionary", systemImage: "character.book.closed") }
            AITab(model: model)
                .tabItem { Label("AI Cleanup", systemImage: "wand.and.stars") }
        }
        .frame(width: 560, height: 420)
    }
}

// MARK: - General

private struct GeneralTab: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: Bindable(model.settings).launchAtLogin)
            Toggle("Interpret voice commands (\"new line\", \"scratch that\", …)", isOn: Bindable(model.settings).voiceCommandsEnabled)

            Picker("Insert text via", selection: Bindable(model.settings).insertionStrategy) {
                ForEach(InsertionStrategy.allCases, id: \.self) { strategy in
                    Text(strategy.label).tag(strategy)
                }
            }
            Toggle("Restore clipboard after inserting", isOn: Bindable(model.settings).restoreClipboard)
                .disabled(model.settings.insertionStrategy != .paste)

            LabeledContent("Release microphone after") {
                HStack {
                    Slider(value: Bindable(model.settings).micIdleTimeout, in: 10...120, step: 5)
                        .frame(width: 180)
                    Text("\(Int(model.settings.micIdleTimeout)) s")
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
            }
            Text("The mic stays warm between dictations for instant starts; this controls when the orange indicator dot clears.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Keys

private struct KeysTab: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section {
                keyRow(
                    title: "Hold to talk",
                    subtitle: "Hold down, speak, release to insert",
                    binding: model.settings.holdBinding,
                    target: .hold
                )
                keyRow(
                    title: "Toggle dictation",
                    subtitle: "Tap to start, tap again to stop",
                    binding: model.settings.toggleBinding,
                    target: .toggle
                )
            } footer: {
                if let conflict = model.keyCapture.lastConflict {
                    Text(conflict)
                        .foregroundStyle(.red)
                }
            }

            if fnGlobeConflict {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(
                            "Your fn / 🌐 key also triggers a system action, which will fire alongside dictation.",
                            systemImage: "exclamationmark.triangle"
                        )
                        Text("Set “Press 🌐 key” to “Do Nothing” in System Settings → Keyboard.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Open Keyboard Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            }

            Text("Press Esc while recording to cancel. While capturing, press the key or mouse button you want — modifier keys alone (fn, right ⌘…) and extra mouse buttons (middle, side) are allowed.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
    }

    private var fnGlobeConflict: Bool {
        guard model.settings.holdBinding?.keyCode == KeyCodes.fn
                || model.settings.toggleBinding?.keyCode == KeyCodes.fn else { return false }
        let value = CFPreferencesCopyAppValue(
            "AppleFnUsageType" as CFString,
            "com.apple.HIToolbox" as CFString
        ) as? Int
        return (value ?? 1) != 0
    }

    private func keyRow(
        title: String,
        subtitle: String,
        binding: KeyBinding?,
        target: KeyCaptureController.Target
    ) -> some View {
        LabeledContent {
            HStack(spacing: 6) {
                Button {
                    if model.keyCapture.capturing == target {
                        model.keyCapture.endCapture()
                    } else {
                        model.keyCapture.beginCapture(for: target)
                    }
                } label: {
                    Text(model.keyCapture.capturing == target
                         ? "Press a key…"
                         : (binding?.displayString ?? "None"))
                    .frame(minWidth: 90)
                }
                Button {
                    model.keyCapture.clearBinding(for: target)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(binding == nil)
            }
        } label: {
            Text(title)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Models

private struct ModelsTab: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            ForEach(ModelVariant.catalog) { variant in
                modelRow(variant)
            }
            Text("Models run entirely on this Mac. First activation optimizes the model for the Neural Engine and can take a minute or two.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
    }

    @ViewBuilder
    private func modelRow(_ variant: ModelVariant) -> some View {
        let manager = model.modelManager
        LabeledContent {
            HStack(spacing: 8) {
                switch manager.phase {
                case .downloading(let active, let progress) where active == variant.id:
                    ProgressView(value: progress)
                        .frame(width: 90)
                case .loading(let active) where active == variant.id:
                    ProgressView()
                        .controlSize(.small)
                default:
                    if manager.activeVariant == variant.id {
                        Label("Active", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button(manager.isDownloaded(variant.id) ? "Activate" : "Download") {
                            Task { await manager.activate(variant.id) }
                        }
                        .disabled(manager.isBusy)
                        if manager.isDownloaded(variant.id) {
                            Button {
                                manager.delete(variant.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .disabled(manager.isBusy)
                        }
                    }
                }
            }
        } label: {
            Text(variant.displayName)
            Text("\(variant.sizeMB) MB — \(variant.blurb)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Dictionary

private struct DictionaryTab: View {
    @Bindable var model: AppModel
    @State private var newBiasWord = ""

    var body: some View {
        Form {
            Section("Vocabulary") {
                Text("Names and jargon Whisper should recognize (e.g. “Scream”, “WhisperKit”).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(model.dictionary.biasWords.indices, id: \.self) { index in
                    HStack {
                        Text(model.dictionary.biasWords[index])
                        Spacer()
                        Button {
                            model.dictionary.biasWords.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                HStack {
                    TextField("Add word or phrase", text: $newBiasWord)
                        .onSubmit(addBiasWord)
                    Button("Add", action: addBiasWord)
                        .disabled(newBiasWord.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section("Replacements") {
                Text("Applied to every transcript, in order, on whole words.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(Bindable(model.dictionary).rules) { $rule in
                    HStack {
                        TextField("Find", text: $rule.find)
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.secondary)
                        TextField("Replace", text: $rule.replace)
                        Toggle("Aa", isOn: $rule.caseSensitive)
                            .toggleStyle(.button)
                            .help("Case sensitive")
                        Button {
                            model.dictionary.rules.removeAll { $0.id == rule.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button("Add Rule") {
                    model.dictionary.rules.append(DictionaryRule(find: "", replace: ""))
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func addBiasWord() {
        let word = newBiasWord.trimmingCharacters(in: .whitespaces)
        guard !word.isEmpty else { return }
        model.dictionary.biasWords.append(word)
        newBiasWord = ""
    }
}

// MARK: - AI Cleanup

private struct AITab: View {
    @Bindable var model: AppModel
    @State private var availableModels: [String] = []
    @State private var reachable: Bool?

    var body: some View {
        Form {
            Section {
                Toggle("Clean up transcripts with a local AI model", isOn: Bindable(model.settings).cleanupEnabled)
                Text("Removes filler words and fixes punctuation using Ollama on this Mac. If Ollama is off or slow, the raw transcript is inserted — dictation never blocks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Ollama") {
                LabeledContent("Status") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(reachable == true ? Color.green : (reachable == false ? .red : .secondary.opacity(0.4)))
                            .frame(width: 9, height: 9)
                        Text(reachable == true ? "Running" : (reachable == false ? "Not reachable" : "Checking…"))
                        Button("Refresh") {
                            Task { await refresh() }
                        }
                        .controlSize(.small)
                    }
                }
                if availableModels.isEmpty {
                    LabeledContent("Model") {
                        TextField("model name", text: Bindable(model.settings).ollamaModel)
                            .frame(width: 180)
                    }
                } else {
                    Picker("Model", selection: Bindable(model.settings).ollamaModel) {
                        ForEach(availableModels, id: \.self) { name in
                            Text(name).tag(name)
                        }
                        if !availableModels.contains(model.settings.ollamaModel) {
                            Text(model.settings.ollamaModel).tag(model.settings.ollamaModel)
                        }
                    }
                }
            }

            Section("Tone by app") {
                Text("When dictating into these apps, the cleanup prompt adapts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(model.cleanup.tonePresets) { preset in
                    LabeledContent(preset.displayName) {
                        Text(preset.prompt)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .task { await refresh() }
    }

    private func refresh() async {
        let client = OllamaClient()
        do {
            availableModels = try await client.listModels()
            reachable = true
        } catch {
            availableModels = []
            reachable = false
        }
    }
}
