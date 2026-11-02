import AppKit
import SwiftUI

/// A small floating, non-activating chat panel. Opened/closed by tapping the
/// roaming pet; repositioned to sit just above wherever the pet currently is
/// each time it's shown, since the pet keeps walking while the panel is closed.
@MainActor
final class ChatWindowController {
    private let session = ClaudeChatSession()
    private var panel: NSPanel?

    /// Called each time we need to know where to anchor the popup.
    var anchorProvider: (() -> CGPoint)?

    func toggle() {
        if let panel, panel.isVisible {
            panel.orderOut(nil)
            return
        }
        show()
    }

    private func show() {
        let width: CGFloat = 300
        let height: CGFloat = 380

        let anchor = anchorProvider?() ?? CGPoint(x: 200, y: 200)
        var origin = CGPoint(x: anchor.x - width / 2, y: anchor.y)

        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - width - 8)
            if origin.y + height > visible.maxY - 8 {
                origin.y = visible.maxY - height - 8
            }
            origin.y = max(origin.y, visible.minY + 8)
        }

        if let panel {
            panel.setFrameOrigin(origin)
            panel.orderFrontRegardless()
            return
        }

        let content = ChatView(session: session, onClose: { [weak self] in
            self?.panel?.orderOut(nil)
        })
        let hosting = NSHostingView(rootView: content)
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)

        let newPanel = NSPanel(
            contentRect: NSRect(origin: origin, size: NSSize(width: width, height: height)),
            styleMask: [.titled, .closable, .nonactivatingPanel, .utilityWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newPanel.titlebarAppearsTransparent = true
        newPanel.titleVisibility = .hidden
        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.hidesOnDeactivate = false
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.contentView = hosting
        newPanel.standardWindowButton(.zoomButton)?.isHidden = true
        newPanel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.orderFrontRegardless()
        panel = newPanel
    }
}
