import AppKit
import JarvisCore
import SwiftUI

@MainActor
public final class NotchPanelController {
    private let panel: NotchPanel
    private weak var model: JarvisAppModel?
    private let width: CGFloat = 420
    private let minHeight: CGFloat = 150
    private var currentHeight: CGFloat = 150

    public init(model: JarvisAppModel) {
        self.model = model
        panel = NotchPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        // Above the menu bar so the panel reads as growing out of the notch.
        panel.level = .mainMenu + 3
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.hidesOnDeactivate = false

        let root = NotchRootView(model: model) { [weak self] height in
            self?.applyMeasuredHeight(height)
        }
        let hosting = NSHostingView(rootView: root)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
    }

    public func show() {
        updateFrame(animated: false)
        panel.orderFrontRegardless()
    }

    public func hide() {
        panel.orderOut(nil)
    }

    /// Grow/shrink the panel to fit the SwiftUI content, staying anchored to the
    /// top of the screen so it expands downward out of the notch.
    private func applyMeasuredHeight(_ height: CGFloat) {
        guard let screen = anchorScreen else { return }
        let maxHeight = screen.frame.height - 48
        let clamped = min(max(height, minHeight), maxHeight)
        guard abs(clamped - currentHeight) > 0.5 else { return }
        currentHeight = clamped
        if panel.isVisible {
            updateFrame(animated: true)
        }
    }

    private func updateFrame(animated: Bool) {
        guard let screen = anchorScreen else { return }
        let frame = screen.frame
        let x = frame.midX - width / 2
        let y = frame.maxY - currentHeight
        panel.setFrame(NSRect(x: x, y: y, width: width, height: currentHeight), display: true, animate: animated)
    }

    /// The screen that actually owns the menu bar / notch (where the mouse is if
    /// possible, otherwise the main screen).
    private var anchorScreen: NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    }
}

private final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
