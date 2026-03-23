# SwitchTab

Production-style macOS utility that replaces default app switching with a Space-aware switcher and adds Dock hover previews using AppKit.

## Setup

1. Open `SwitchTab.xcodeproj` in Xcode.
2. Run the `SwitchTab` target.
3. On first launch, grant:
   - `Accessibility`
   - `Input Monitoring`
4. Quit and reopen the app after granting permissions.

## Permissions and Runtime Requirements

- `Accessibility` is required for raising exact windows, inspecting Dock accessibility elements, and reading deeper metadata.
- `Input Monitoring` is required for a HID-level `Command + Tab` override.
- `App Sandbox` should remain disabled for this utility-style app.

## Main Components

- `AppSwitcherManager`: intercepts `Command + Tab`, limits results to the active Space, and commits selection on key release.
- `SpaceAwareWindowService`: reads CGWindow metadata, groups windows by app, and focuses exact windows.
- `DockPreviewManager`: watches global mouse movement and uses Accessibility hit-testing against Dock elements.
- `ThumbnailCache`: caches `CGWindow` thumbnails for previews.
- `AccessibilityService`: permission checks, AX traversal, exact window focus, and Dock hit-testing helpers.
- `FloatingSwitcherWindow`: centered Windows-style switcher for the active Space.
- `PreviewPanelWindow`: thumbnail preview panel shown above the Dock.

## Public API Limitations

- macOS does not expose a first-class public API for Dock hover events. This app uses Accessibility hit-testing as the closest practical approach.
- Exact browser-tab previews are not guaranteed through public APIs. The app falls back to window titles and AX metadata where available.
- Overriding the system `Command + Tab` is sensitive to TCC permissions and may still be affected by OS-level behavior after updates.

## Fallback Strategies

- If Dock hit-testing cannot map the hovered icon to a running app, the preview panel stays hidden instead of guessing.
- If exact AX window raise fails, the app falls back to activating the owning application.
- If `Command + Tab` interception is blocked by permissions, the app requests permissions and explains the missing access.
