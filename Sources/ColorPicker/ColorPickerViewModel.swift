import AppKit
import SwiftUI

private func simulateClick() {
    guard let current = CGEvent(source: nil) else { return }
    let point = current.location
    if let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                          mouseCursorPosition: point, mouseButton: .left) {
        down.post(tap: .cghidEventTap)
    }
    if let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                        mouseCursorPosition: point, mouseButton: .left) {
        up.post(tap: .cghidEventTap)
    }
}

private func nudgeCursor(dx: CGFloat, dy: CGFloat) {
    guard let current = CGEvent(source: nil) else { return }
    let point = CGPoint(x: current.location.x + dx, y: current.location.y + dy)
    CGWarpMouseCursorPosition(point)
    if let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                          mouseCursorPosition: point, mouseButton: .left) {
        move.post(tap: .cghidEventTap)
    }
}

@MainActor
final class ColorPickerViewModel: ObservableObject {
    static let shared = ColorPickerViewModel()

    @Published var lastColor: NSColor?
    @Published var hexString: String = ""
    @Published var showCopiedFeedback: Bool = false
    @Published var colorHistory: [NSColor] = []

    private var arrowKeyMonitor: Any?

    func pickColor() {
        NSApp.activate(ignoringOtherApps: true)
        installArrowKeyMonitor()
        let sampler = NSColorSampler()
        sampler.show { [weak self] selectedColor in
            guard let self else { return }
            Task { @MainActor in
                self.removeArrowKeyMonitor()
                guard let selectedColor else { return }
                self.lastColor = selectedColor
                self.hexString = selectedColor.toHexString()
                self.colorHistory.insert(selectedColor, at: 0)
                if self.colorHistory.count > 10 {
                    self.colorHistory.removeLast()
                }
                self.copyToClipboard()

                if NSEvent.modifierFlags.contains(.shift) {
                    self.pickColor()
                }
            }
        }
    }

    private func installArrowKeyMonitor() {
        removeArrowKeyMonitor()
        arrowKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 36, 76: simulateClick() // Return, keypad Enter
            case 123: nudgeCursor(dx: -1, dy: 0)
            case 124: nudgeCursor(dx:  1, dy: 0)
            case 125: nudgeCursor(dx: 0, dy:  1)
            case 126: nudgeCursor(dx: 0, dy: -1)
            default: break
            }
        }
    }

    private func removeArrowKeyMonitor() {
        if let monitor = arrowKeyMonitor {
            NSEvent.removeMonitor(monitor)
            arrowKeyMonitor = nil
        }
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
