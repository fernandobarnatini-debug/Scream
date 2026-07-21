import AVFoundation
import ApplicationServices
import AppKit
import Observation

@MainActor
@Observable
final class PermissionsModel {
    enum MicStatus {
        case notDetermined
        case granted
        case denied
    }

    private(set) var microphone: MicStatus = .notDetermined
    private(set) var accessibility = false

    private var pollTask: Task<Void, Never>?

    var allGranted: Bool {
        microphone == .granted && accessibility
    }

    func refresh() {
        microphone = switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: .granted
        case .denied, .restricted: .denied
        case .notDetermined: .notDetermined
        @unknown default: .denied
        }
        accessibility = AXIsProcessTrusted()
    }

    func requestMicrophone() async {
        if microphone == .denied {
            Self.openSystemSettings(pane: "Privacy_Microphone")
            return
        }
        _ = await AVCaptureDevice.requestAccess(for: .audio)
        refresh()
    }

    func requestAccessibility() {
        // Literal key for kAXTrustedCheckOptionPrompt — the C global is not concurrency-safe in Swift 6.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            Self.openSystemSettings(pane: "Privacy_Accessibility")
        }
        refresh()
    }

    /// Polls while the onboarding window is visible so status rows flip live
    /// as the user grants permissions in System Settings.
    func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    private static func openSystemSettings(pane: String) {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!
        NSWorkspace.shared.open(url)
    }
}
