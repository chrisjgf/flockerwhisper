import AppKit
import SwiftUI

private final class FloatingHUDPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class OverlayPanelController {
    private var panel: FloatingHUDPanel?
    private var hostingView: NSHostingView<AnyView>?

    func show<Content: View>(@ViewBuilder content: () -> Content) {
        let wrapped = AnyView(content())

        if let existingPanel = panel, let existingHosting = hostingView {
            existingHosting.rootView = wrapped
            resizeAndCenter(panel: existingPanel, hostingView: existingHosting)
            if !existingPanel.isVisible {
                existingPanel.alphaValue = 0
                existingPanel.orderFrontRegardless()
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.14
                    existingPanel.animator().alphaValue = 1
                }
            }
            return
        }

        let hosting = NSHostingView(rootView: wrapped)
        let size = hosting.fittingSize

        let panel = FloatingHUDPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false // Shadow rendered inside SwiftUI so rounded corners stay crisp
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.contentView = hosting
        panel.alphaValue = 0

        self.panel = panel
        self.hostingView = hosting

        resizeAndCenter(panel: panel, hostingView: hosting)
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.14
            panel.animator().alphaValue = 1
        }
    }

    func updateLayout() {
        guard let panel, let hostingView else { return }
        resizeAndCenter(panel: panel, hostingView: hostingView)
    }

    func hide() {
        guard let panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.14
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak panel] in
            Task { @MainActor in
                panel?.orderOut(nil)
            }
        })
    }

    private func resizeAndCenter(panel: NSPanel, hostingView: NSHostingView<AnyView>) {
        hostingView.layoutSubtreeIfNeeded()
        let targetSize = hostingView.fittingSize
        let screen = Self.activeScreen()
        let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let origin = NSPoint(
            x: round(visibleFrame.midX - targetSize.width / 2),
            y: round(visibleFrame.midY - targetSize.height / 2)
        )
        panel.setFrame(NSRect(origin: origin, size: targetSize), display: true)
    }

    private static func activeScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main
    }
}
