import AppKit

extension NSColor {
    func toHexString() -> String {
        guard let color = usingColorSpace(.sRGB) else {
            return "#000000"
        }
        let r = Int(round(color.redComponent * 255))
        let g = Int(round(color.greenComponent * 255))
        let b = Int(round(color.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
