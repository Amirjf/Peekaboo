import AppKit
import SwiftUI

/// A borderless, non-activating panel that sits over the menu bar, centered on the notch.
final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Lets the first click on the notch work without focusing Peekaboo first.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
final class NotchPanelController {
    private let panel: NotchPanel
    private let model: NotchModel
    private var mouseTimer: Timer?
    private let panelSize = CGSize(width: 680, height: 380)

    init(model: NotchModel) {
        self.model = model
        panel = NotchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isMovable = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        let host = FirstMouseHostingView(rootView: NotchRootView(model: model))
        host.sizingOptions = []
        panel.contentView = host

        reposition()
        panel.orderFrontRegardless()

        // Poll the cursor instead of using tracking areas: the panel ignores mouse events
        // outside the notch so clicks on the menu bar still go through.
        mouseTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkMouse() }
        }
    }

    /// Picks the screen with a notch (or the main one) and centers the panel at its top.
    func reposition() {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? NSScreen.screens.first else { return }
        model.geometry = NotchGeometry(screen: screen)
        let f = screen.frame
        panel.setFrame(NSRect(x: f.midX - panelSize.width / 2, y: f.maxY - panelSize.height, width: panelSize.width, height: panelSize.height), display: true)
    }

    private func checkMouse() {
        let mouse = NSEvent.mouseLocation
        let f = panel.frame
        let hit = model.hitSize
        let rect = NSRect(x: f.midX - hit.width / 2, y: f.maxY - hit.height, width: hit.width, height: hit.height)
        let inside = model.presentation != .hidden && rect.insetBy(dx: -4, dy: -4).contains(mouse)
        if panel.ignoresMouseEvents == inside { panel.ignoresMouseEvents = !inside }
        model.updateMouse(inside: inside)
    }
}
