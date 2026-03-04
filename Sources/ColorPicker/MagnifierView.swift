import AppKit

final class MagnifierView: NSView {
    /// The captured screen region (gridSize × gridSize pixels).
    var capturedImage: CGImage?
    /// The color of the center pixel.
    var centerColor: NSColor = .clear
    /// Pre-formatted HEX string for the label.
    var hexString: String = ""

    // MARK: - Layout constants

    private let gridSize = 15          // pixels captured in each axis
    private let pixelCellSize: CGFloat = 9
    private let gridLineWidth: CGFloat = 0.5
    private let cornerRadius: CGFloat = 10
    private let labelHeight: CGFloat = 26
    private let labelPadding: CGFloat = 4

    var gridSide: CGFloat { CGFloat(gridSize) * pixelCellSize }

    var idealSize: NSSize {
        NSSize(width: gridSide, height: gridSide + labelHeight + labelPadding)
    }

    // MARK: - Transparent cursor

    private static let blankCursor: NSCursor = {
        let image = NSImage(size: NSSize(width: 1, height: 1))
        return NSCursor(image: image, hotSpot: .zero)
    }()

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.cursorUpdate, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func cursorUpdate(with event: NSEvent) {
        Self.blankCursor.set()
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let gridSide = CGFloat(gridSize) * pixelCellSize
        let gridRect = CGRect(x: 0, y: labelHeight + labelPadding, width: gridSide, height: gridSide)

        drawGrid(ctx: ctx, in: gridRect)
        drawGridLines(ctx: ctx, in: gridRect)
        drawCrosshair(ctx: ctx, in: gridRect)
        drawHexLabel(ctx: ctx, gridSide: gridSide)
    }

    // MARK: - Pixel grid

    private func drawGrid(ctx: CGContext, in rect: CGRect) {
        ctx.saveGState()

        // Clip to rounded rect
        let clipPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        ctx.addPath(clipPath)
        ctx.clip()

        if let image = capturedImage {
            // Draw with nearest-neighbor interpolation for crisp pixel blocks
            ctx.interpolationQuality = .none
            ctx.draw(image, in: rect)
        } else {
            ctx.setFillColor(NSColor.windowBackgroundColor.cgColor)
            ctx.fill(rect)
        }

        ctx.restoreGState()

        // Draw rounded border
        ctx.saveGState()
        ctx.addPath(clipPath)
        ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.3).cgColor)
        ctx.setLineWidth(1)
        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: - Grid lines

    private func drawGridLines(ctx: CGContext, in rect: CGRect) {
        ctx.saveGState()

        let clipPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        ctx.addPath(clipPath)
        ctx.clip()

        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.15).cgColor)
        ctx.setLineWidth(gridLineWidth)

        for i in 1..<gridSize {
            let x = rect.minX + CGFloat(i) * pixelCellSize
            ctx.move(to: CGPoint(x: x, y: rect.minY))
            ctx.addLine(to: CGPoint(x: x, y: rect.maxY))

            let y = rect.minY + CGFloat(i) * pixelCellSize
            ctx.move(to: CGPoint(x: rect.minX, y: y))
            ctx.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        ctx.strokePath()

        ctx.restoreGState()
    }

    // MARK: - Center crosshair

    private func drawCrosshair(ctx: CGContext, in rect: CGRect) {
        let center = gridSize / 2
        let crosshairRect = CGRect(
            x: rect.minX + CGFloat(center) * pixelCellSize,
            y: rect.minY + CGFloat(center) * pixelCellSize,
            width: pixelCellSize,
            height: pixelCellSize
        )

        // Black outer stroke
        ctx.setStrokeColor(NSColor.black.cgColor)
        ctx.setLineWidth(2.5)
        ctx.stroke(crosshairRect.insetBy(dx: -1, dy: -1))

        // White inner stroke
        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.setLineWidth(1.5)
        ctx.stroke(crosshairRect)
    }

    // MARK: - HEX label

    private func drawHexLabel(ctx: CGContext, gridSide: CGFloat) {
        let pillWidth = gridSide
        let pillRect = CGRect(x: 0, y: 0, width: pillWidth, height: labelHeight)
        let pillPath = CGPath(roundedRect: pillRect, cornerWidth: labelHeight / 2, cornerHeight: labelHeight / 2, transform: nil)

        // Dark pill background
        ctx.saveGState()
        ctx.addPath(pillPath)
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.8).cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        // Color swatch dot
        let dotSize: CGFloat = 12
        let dotRect = CGRect(
            x: 8,
            y: (labelHeight - dotSize) / 2,
            width: dotSize,
            height: dotSize
        )
        ctx.saveGState()
        ctx.setFillColor(centerColor.cgColor)
        ctx.fillEllipse(in: dotRect)
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.4).cgColor)
        ctx.setLineWidth(0.5)
        ctx.strokeEllipse(in: dotRect)
        ctx.restoreGState()

        // HEX text
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let text = hexString as NSString
        let textSize = text.size(withAttributes: textAttributes)
        let textOrigin = CGPoint(
            x: dotRect.maxX + 6,
            y: (labelHeight - textSize.height) / 2
        )

        // Flip context for text drawing (Core Graphics has inverted Y for text)
        ctx.saveGState()
        let nsContext = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.current = nsContext
        text.draw(at: textOrigin, withAttributes: textAttributes)
        ctx.restoreGState()
    }
}
