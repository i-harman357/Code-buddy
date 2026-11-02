import AppKit
import SwiftUI
import Combine

/// A borderless window that can never take keyboard focus or steal the
/// frontmost app away from the user — the pet should feel like it's
/// wandering "on top of" whatever you're doing, never interrupting it.
private final class PetOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct PetOverlayContentView: View {
    @ObservedObject var model: DockCharacterModel
    let facingRight: Bool
    let isWalking: Bool
    let onTap: () -> Void

    var body: some View {
        DeadpoolCharacterView(model: model, facingRight: facingRight, isWalking: isWalking)
            .background(Color.clear)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
    }
}

/// Owns the roaming desktop-pet window: a small always-on-top panel that
/// walks around the bottom of the screen on its own, sized to just the
/// character so every other click on the desktop passes straight through
/// to whatever is underneath.
@MainActor
final class PetWindowController: ObservableObject {
    static let size = NSSize(width: 130, height: 150)

    private let model = DockCharacterModel()
    private var window: PetOverlayWindow?
    private var movement: PetMovementEngine?
    private var timer: Timer?
    private var onTap: (() -> Void)?

    private var stateSubscription: AnyCancellable?
    private var toggleSubscription: AnyCancellable?

    init(appState: AppState, engine: CheckInEngine, onTap: @escaping () -> Void) {
        self.onTap = onTap
        model.kind = .deadpool

        stateSubscription = engine.$state.sink { [weak self] state in
            self?.model.state = state
            self?.applySpeed(for: state)
        }
        toggleSubscription = appState.$enableDesktopPet.sink { [weak self] enabled in
            enabled ? self?.install() : self?.uninstall()
        }
        if appState.enableDesktopPet {
            install()
        }
    }

    /// Current center point of the pet on screen, in screen coordinates —
    /// used by ChatWindowController to anchor the chat popup near him.
    var currentScreenPosition: CGPoint {
        window?.frame.origin.applying(.init(translationX: Self.size.width / 2, y: Self.size.height))
            ?? .zero
    }

    private func install() {
        guard window == nil else { return }
        let bounds = screenBounds()
        let start = CGPoint(x: bounds.midX, y: bounds.minY)
        movement = PetMovementEngine(startingAt: start, bounds: bounds)

        let content = PetOverlayContentView(
            model: model,
            facingRight: true,
            isWalking: false,
            onTap: { [weak self] in self?.onTap?() }
        )
        let hosting = NSHostingView(rootView: content)
        hosting.frame = NSRect(origin: .zero, size: Self.size)

        let win = PetOverlayWindow(
            contentRect: NSRect(origin: start, size: Self.size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.level = .floating
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        win.ignoresMouseEvents = false
        win.contentView = hosting
        win.orderFrontRegardless()
        window = win

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func uninstall() {
        timer?.invalidate()
        timer = nil
        window?.orderOut(nil)
        window = nil
        movement = nil
    }

    private func applySpeed(for state: CheckInState) {
        guard let movement else { return }
        switch state {
        case .stalling: movement.speed = 150
        case .active: movement.speed = 95
        case .flow: movement.speed = 55
        case .away: movement.speed = 20
        case .stopped: movement.speed = 70
        }
    }

    private func tick() {
        guard let movement, let win = window else { return }
        movement.updateBounds(screenBounds())
        movement.tick(dt: 1.0 / 30.0)
        model.animPhase += 1

        var origin = win.frame.origin
        origin.x = movement.position.x - Self.size.width / 2
        origin.y = movement.position.y
        win.setFrameOrigin(origin)

        let content = PetOverlayContentView(
            model: model,
            facingRight: movement.facingRight,
            isWalking: movement.isWalking,
            onTap: { [weak self] in self?.onTap?() }
        )
        (win.contentView as? NSHostingView<PetOverlayContentView>)?.rootView = content
    }

    private func screenBounds() -> CGRect {
        let visible = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        return CGRect(
            x: visible.minX + Self.size.width / 2,
            y: visible.minY,
            width: max(visible.width - Self.size.width, 1),
            height: 0
        )
    }
}
