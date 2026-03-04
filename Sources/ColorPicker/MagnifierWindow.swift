import AppKit

final class MagnifierWindow: NSPanel {
    init(contentSize: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .screenSaver
        isOpaque = false
        hasShadow = true
        backgroundColor = .clear
        sharingType = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    }

    /// Repositions the window so the pixel grid is centered on the cursor.
    /// The grid sits above the HEX label, so we offset vertically to align
    /// the grid's center (not the window's center) with the cursor.
    func updatePosition(cursorLocation: CGPoint, gridHeight: CGFloat) {
        let size = frame.size
        let labelArea = size.height - gridHeight
        let origin = CGPoint(
            x: cursorLocation.x - size.width / 2,
            y: cursorLocation.y - gridHeight / 2 - labelArea
        )
        setFrameOrigin(origin)
    }

    private func screenContaining(point: CGPoint) -> NSScreen? {
        // NSScreen uses bottom-left origin (same as NSPoint)
        NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
    }
}
