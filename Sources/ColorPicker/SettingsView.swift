import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Pick Color Shortcut:", name: .pickColor)
        }
        .padding()
        .frame(width: 350)
    }
}
