import AppKit
import SwiftUI
import Observation

@MainActor
@Observable
final class PanelDisplayModel {
    enum Display: Equatable {
        case recording
        case transcribing
        case success
        case error(String)
    }

    var display: Display = .recording
}

/// The floating Wispr-style pill. A non-activating panel so the target app
/// keeps key focus (and its caret) the whole time.
@MainActor
final class RecordingPanelController {
    private let displayModel = PanelDisplayModel()
    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?

    private let levelMonitor: AudioLevelMonitor

    init(levelMonitor: AudioLevelMonitor) {
        self.levelMonitor = levelMonitor
    }

    func show(_ display: PanelDisplayModel.Display) {
        hideTask?.cancel()
        hideTask = nil
        displayModel.display = display
        let panel = ensurePanel()
        position(panel)
        panel.orderFrontRegardless()
    }

    func update(_ display: PanelDisplayModel.Display) {
        displayModel.display = display
    }

    func hide() {
        hideTask?.cancel()
        hideTask = nil
        panel?.orderOut(nil)
    }

    func flashSuccessAndHide() {
        displayModel.display = .success
        hideAfter(.milliseconds(600))
    }

    func showErrorAndHide(_ message: String) {
        show(.error(message))
        hideAfter(.seconds(2.5))
    }

    private func hideAfter(_ delay: Duration) {
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.panel?.orderOut(nil)
        }
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 44),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.contentView = NSHostingView(
            rootView: RecordingPillView(model: displayModel, levelMonitor: levelMonitor)
        )
        self.panel = panel
        return panel
    }

    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let frame = panel.frame
        let x = screen.visibleFrame.midX - frame.width / 2
        let y = screen.visibleFrame.minY + 24
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
