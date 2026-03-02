# Color Picker

A lightweight macOS menu bar app for picking colors from anywhere on screen.

Left-click the colored dot to instantly sample a color. The hex value is automatically copied to your clipboard. Right-click for preferences and other options.

## Requirements

- macOS 13+
- Xcode 15+ or Swift 5.9+

## Usage

- **Left-click** the menu bar icon to open the system color sampler and pick a color
- **Shift-click** while the sampler is open to pick a color and immediately reopen the sampler for rapid multi-color selection
- **Arrow keys** while the sampler is open to nudge the cursor by 1 pixel for precise positioning
- **Enter** while the sampler is open to pick the color at the current cursor position
- **Right-click** the menu bar icon to open the context menu:
  - **Color history** — the last 10 picked colors are shown with swatches; click any to copy its hex value
  - **Copy as CSS Variables** — copies all history entries as a `:root {}` block with `--color-1` through `--color-N`
  - **Preferences...** to configure a global keyboard shortcut
  - **Quit** to exit the app
- **Keyboard shortcut** — set a custom global shortcut in Preferences to trigger color picking from anywhere

Arrow keys, Enter, and shift-click require Accessibility permissions (System Settings > Privacy & Security > Accessibility).

## Build

```bash
swift build -c release
```

The built binary will be at `.build/release/ColorPicker`.

## Install

Build and install to `/Applications` in one step:

```bash
swift build -c release && cp -fR ColorPicker.app /Applications/ && cp -f .build/release/ColorPicker /Applications/ColorPicker.app/Contents/MacOS/ColorPicker
```

## Dependencies

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) — global keyboard shortcut support
