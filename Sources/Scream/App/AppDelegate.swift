import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    private var onboardingWindow: NSWindow?
    private var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.app.info("Scream launched")
        model.bootstrap()
        enableLaunchAtLoginOnce()
        if !model.settings.hasCompletedOnboarding {
            showOnboarding()
        } else if !Self.launchedAsLoginItem {
            showMainWindow()
        }
    }

    // Closing the window leaves dictation running in the menu bar.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        }
        return true
    }

    func showMainWindow() {
        if mainWindow == nil {
            let view = MainWindowView(model: model) { [weak self] in
                self?.showOnboarding()
            }
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "Scream"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            mainWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
    }

    func showOnboarding() {
        if onboardingWindow == nil {
            let view = OnboardingView(model: model) { [weak self] in
                self?.onboardingWindow?.close()
            }
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "Set Up Scream"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            onboardingWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow?.makeKeyAndOrderFront(nil)
    }

    /// Turns launch-at-login on the first time this build runs; the Settings
    /// toggle remains the source of truth for every run after that.
    private func enableLaunchAtLoginOnce() {
        let key = "didDefaultLaunchAtLogin"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        model.settings.launchAtLogin = true
    }

    /// SMAppService login-item launches carry an 'oapp' Apple event tagged
    /// 'lgit' in its 'prdt' parameter; a Finder/Spotlight launch does not.
    private static var launchedAsLoginItem: Bool {
        let keyAEPropData = AEKeyword(0x7072_6474) // 'prdt'
        let launchedAsLogInItem: UInt32 = 0x6C67_6974 // 'lgit'
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventID == kAEOpenApplication
        else { return false }
        return event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == launchedAsLogInItem
    }
}
