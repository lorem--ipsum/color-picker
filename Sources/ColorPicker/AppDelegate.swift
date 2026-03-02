import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let viewModel = ColorPickerViewModel.shared
    private var cancellable: AnyCancellable?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = makeMenuBarIcon(color: viewModel.lastColor)
            button.target = self
            button.action = #selector(statusBarClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        cancellable = viewModel.$lastColor
            .receive(on: RunLoop.main)
            .sink { [weak self] color in
                self?.statusItem.button?.image = makeMenuBarIcon(color: color)
            }
    }

    @objc private func statusBarClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showMenu()
        } else {
            viewModel.pickColor()
        }
    }

    private func showMenu() {
        let menu = NSMenu()

        if !viewModel.colorHistory.isEmpty {
            for (index, color) in viewModel.colorHistory.enumerated() {
                let hex = color.toHexString()
                let item = NSMenuItem(
                    title: hex,
                    action: #selector(copyHistoryItem(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.tag = index
                item.image = makeSwatchImage(color: color)
                menu.addItem(item)
            }

            menu.addItem(.separator())

            let cssItem = NSMenuItem(
                title: "Copy as CSS Variables",
                action: #selector(copyAsCSSVars),
                keyEquivalent: ""
            )
            cssItem.target = self
            menu.addItem(cssItem)

            menu.addItem(.separator())
        }

        let prefsItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func copyHistoryItem(_ sender: NSMenuItem) {
        let index = sender.tag
        guard index >= 0, index < viewModel.colorHistory.count else { return }
        let hex = viewModel.colorHistory[index].toHexString()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hex, forType: .string)
    }

    @objc private func copyAsCSSVars() {
        viewModel.copyAllAsCSSVars()
    }

    @objc private func openPreferences() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentViewController: NSHostingController(rootView: SettingsView())
            )
            window.title = "Color Picker Settings"
            window.styleMask = [.titled, .closable]
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func makeSwatchImage(color: NSColor) -> NSImage {
        let size = NSSize(width: 12, height: 12)
        let image = NSImage(size: size, flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}
