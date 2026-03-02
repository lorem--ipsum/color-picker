import AppKit

func makeMenuBarIcon(color: NSColor?) -> NSImage {
    let size = NSSize(width: 18, height: 18)
    let image = NSImage(size: size, flipped: false) { rect in
        let fillColor = color ?? NSColor.gray
        fillColor.setFill()

        let circlePath = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
        circlePath.fill()

        NSColor.labelColor.withAlphaComponent(0.3).setStroke()
        circlePath.lineWidth = 1
        circlePath.stroke()

        return true
    }
    image.isTemplate = false
    return image
}
