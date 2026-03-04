import AppKit
import CoreGraphics

@MainActor
final class MagnifierController {
    private var window: MagnifierWindow?
    private var magnifierView: MagnifierView?
    private var updateTimer: Timer?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var eventTapUserInfo: UnsafeMutableRawPointer?

    private var onColorPicked: ((NSColor) -> Void)?
    private var onCancel: (() -> Void)?
    private var isActive = false

    private let gridSize = 15

    // MARK: - Public API

    /// Shows the magnifier. `onColorPicked` fires each time a color is picked
    /// (including repeated shift-clicks). `onCancel` fires if dismissed via Escape.
    func show(onColorPicked: @escaping (NSColor) -> Void, onCancel: @escaping () -> Void) {
        if isActive { return }

        self.onColorPicked = onColorPicked
        self.onCancel = onCancel

        guard checkScreenCapturePermission() else {
            onCancel()
            return
        }

        isActive = true
        setupWindow()
        installEventTap()
        NSCursor.hide()
        startUpdateLoop()
    }

    // MARK: - Permission

    private func checkScreenCapturePermission() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }
        CGRequestScreenCaptureAccess()
        return false
    }

    // MARK: - Window setup

    private func setupWindow() {
        let view = MagnifierView()
        let size = view.idealSize
        view.frame = NSRect(origin: .zero, size: size)

        let panel = MagnifierWindow(contentSize: size)
        panel.contentView = view
        panel.orderFrontRegardless()

        self.magnifierView = view
        self.window = panel
    }

    // MARK: - Update loop (60 Hz)

    private func startUpdateLoop() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard let view = magnifierView, let window = window else { return }

        let cursorLocation = NSEvent.mouseLocation
        let captureCenter = cgPointFromNSPoint(cursorLocation)

        // Capture a gridSize×gridSize region around the cursor (pixel-aligned)
        if let image = captureScreen(around: captureCenter, size: gridSize) {
            view.capturedImage = image

            // Extract center pixel color from the captured image
            let centerIdx = gridSize / 2
            let rep = NSBitmapImageRep(cgImage: image)
            if let color = rep.colorAt(x: centerIdx, y: centerIdx) {
                view.centerColor = color
                view.hexString = color.toHexString()
            }
        }

        view.needsDisplay = true
        window.updatePosition(cursorLocation: cursorLocation, gridHeight: view.gridSide)
    }

    // MARK: - Screen capture

    /// Converts NSEvent.mouseLocation (bottom-left origin) to CGDisplay coordinates (top-left origin).
    private func cgPointFromNSPoint(_ point: NSPoint) -> CGPoint {
        guard let mainScreen = NSScreen.screens.first else {
            return CGPoint(x: point.x, y: point.y)
        }
        return CGPoint(x: point.x, y: mainScreen.frame.height - point.y)
    }

    private func captureScreen(around center: CGPoint, size: Int) -> CGImage? {
        // Use integer half so the center pixel lands exactly at index (size/2, size/2)
        let half = size / 2
        let captureRect = CGRect(
            x: floor(center.x) - CGFloat(half),
            y: floor(center.y) - CGFloat(half),
            width: CGFloat(size),
            height: CGFloat(size)
        )
        return CGWindowListCreateImage(
            captureRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .nominalResolution
        )
    }

    // MARK: - Event tap (mouse clicks + keyboard)

    private func installEventTap() {
        let eventMask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.keyDown.rawValue)

        let selfPtr = Unmanaged.passRetained(self).toOpaque()
        eventTapUserInfo = selfPtr

        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, userInfo in
                guard let userInfo = userInfo else { return Unmanaged.passRetained(event) }

                // Re-enable tap if the system disabled it
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    let controller = Unmanaged<MagnifierController>.fromOpaque(userInfo).takeUnretainedValue()
                    DispatchQueue.main.async {
                        if let tap = controller.eventTap {
                            CGEvent.tapEnable(tap: tap, enable: true)
                        }
                    }
                    return Unmanaged.passRetained(event)
                }

                let controller = Unmanaged<MagnifierController>.fromOpaque(userInfo).takeUnretainedValue()

                // --- Mouse events ---

                if type == .leftMouseDown {
                    let shiftHeld = event.flags.contains(.maskShift)
                    DispatchQueue.main.async {
                        controller.pickColorAtCursor(continueSession: shiftHeld)
                    }
                    return nil // swallow
                }

                if type == .leftMouseUp {
                    return nil // swallow
                }

                // --- Keyboard events ---

                if type == .keyDown {
                    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                    switch keyCode {
                    case 53: // Escape
                        DispatchQueue.main.async { controller.cancel() }
                        return nil
                    case 36, 76: // Return, keypad Enter
                        DispatchQueue.main.async { controller.pickColorAtCursor(continueSession: false) }
                        return nil
                    case 123: // Left arrow
                        DispatchQueue.main.async { controller.nudgeCursor(dx: -1, dy: 0) }
                        return nil
                    case 124: // Right arrow
                        DispatchQueue.main.async { controller.nudgeCursor(dx: 1, dy: 0) }
                        return nil
                    case 125: // Down arrow
                        DispatchQueue.main.async { controller.nudgeCursor(dx: 0, dy: 1) }
                        return nil
                    case 126: // Up arrow
                        DispatchQueue.main.async { controller.nudgeCursor(dx: 0, dy: -1) }
                        return nil
                    default:
                        return Unmanaged.passRetained(event)
                    }
                }

                return Unmanaged.passRetained(event)
            },
            userInfo: selfPtr
        )

        if let tap = eventTap {
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    // MARK: - Cursor nudge

    private func nudgeCursor(dx: CGFloat, dy: CGFloat) {
        guard let current = CGEvent(source: nil) else { return }
        let point = CGPoint(x: current.location.x + dx, y: current.location.y + dy)
        CGWarpMouseCursorPosition(point)
        if let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                              mouseCursorPosition: point, mouseButton: .left) {
            move.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Pick / cancel / dismiss

    private func pickColorAtCursor(continueSession: Bool) {
        let cursorLocation = cgPointFromNSPoint(NSEvent.mouseLocation)
        let captureRect = CGRect(
            x: floor(cursorLocation.x),
            y: floor(cursorLocation.y),
            width: 1,
            height: 1
        )
        if let image = CGWindowListCreateImage(
            captureRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .nominalResolution
        ) {
            let rep = NSBitmapImageRep(cgImage: image)
            if let color = rep.colorAt(x: 0, y: 0) {
                onColorPicked?(color)
            }
        }

        if !continueSession {
            dismiss()
        }
    }

    private func cancel() {
        onCancel?()
        dismiss()
    }

    private func dismiss() {
        guard isActive else { return }
        isActive = false

        updateTimer?.invalidate()
        updateTimer = nil

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            if let ptr = eventTapUserInfo {
                Unmanaged<MagnifierController>.fromOpaque(ptr).release()
                eventTapUserInfo = nil
            }
            eventTap = nil
            runLoopSource = nil
        }

        window?.orderOut(nil)
        window = nil
        magnifierView = nil

        NSCursor.unhide()

        onColorPicked = nil
        onCancel = nil
    }
}
