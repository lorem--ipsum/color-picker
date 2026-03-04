import AppKit
import SwiftUI

@MainActor
final class ColorPickerViewModel: ObservableObject {
    static let shared = ColorPickerViewModel()

    @Published var lastColor: NSColor?
    @Published var hexString: String = ""
    @Published var showCopiedFeedback: Bool = false
    @Published var colorHistory: [NSColor] = []

    private let magnifier = MagnifierController()

    func pickColor() {
        magnifier.show(
            onColorPicked: { [weak self] color in
                guard let self else { return }
                Task { @MainActor in
                    self.lastColor = color
                    self.hexString = color.toHexString()
                    self.colorHistory.insert(color, at: 0)
                    if self.colorHistory.count > 10 {
                        self.colorHistory.removeLast()
                    }
                    self.copyToClipboard()
                }
            },
            onCancel: {}
        )
    }

    func copyToClipboard() {
        guard !hexString.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hexString, forType: .string)
        showCopiedFeedback = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            showCopiedFeedback = false
        }
    }

    func copyAllAsCSSVars() {
        guard !colorHistory.isEmpty else { return }
        var lines = [":root {"]
        for (index, color) in colorHistory.enumerated() {
            lines.append("  --color-\(index + 1): \(color.toHexString());")
        }
        lines.append("}")
        let css = lines.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(css, forType: .string)
    }
}
