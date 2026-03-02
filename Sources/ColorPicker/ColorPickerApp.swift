import KeyboardShortcuts
import SwiftUI

@main
struct ColorPickerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)

        KeyboardShortcuts.onKeyUp(for: .pickColor) {
            Task { @MainActor in
                ColorPickerViewModel.shared.pickColor()
            }
        }
    }

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
