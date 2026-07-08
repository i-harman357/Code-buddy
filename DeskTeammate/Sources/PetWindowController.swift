import AppKit
import SwiftUI
import Combine

/// A floating, always-on-top panel that can never take keyboard focus or
/// steal the frontmost app away from the user — the pet should feel like
/// it's wandering "on top of" whatever you're doing, never interrupting it.
private final class PetOverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct PetOverlayContentView: View {
    @ObservedObject var model: DockCharacterModel
    let facingRight: Bool
    let isWalking: Bool
    let bubbleText: String?
    let onTap: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            DeadpoolBubbleOverlay(text: bubbleText)
            Spacer(minLength: 0)
            DeadpoolCharacterView(model: model, facingRight: facingRight, isWalking: isWalking)
                .frame(width: 150, height: PetWindowController.characterHeight)
                .contentShape(Rectangle())
                .gesture(
                    // minimumDistance 0 so both a plain click and a drag start
                    // here; onEnded tells them apart by how far it traveled.
                    DragGesture(minimumDistance: 0)
                        .onChanged { onDragChanged($0.translation) }
                        .onEnded { value in
                            let distance = hypot(value.translation.width, value.translation.height)
                            if distance < 4 {
                                onTap()
                            } else {
                                onDragEnded()
                            }
                        }
                )
        }
        .frame(width: PetWindowController.size.width, height: PetWindowController.size.height, alignment: .bottom)
    }
}

/// Owns the roaming desktop-pet window: a small always-on-top panel that
/// walks around the bottom of the screen on its own, reacts to check-in
/// state changes with a speech bubble, and can be dragged anywhere — a drag
/// pins it in place until the next state change resumes the walk.
@MainActor
final class PetWindowController: ObservableObject {
    static let size = NSSize(width: 220, height: 300)
    /// Height of just the character's own frame within `size`, used both to
    /// lay out the view and to anchor the chat popup near its head instead
    /// of the top of the (taller, bubble-reserving) window.
    static let characterHeight: CGFloat = 180

    private let model = DockCharacterModel()
    private weak var engine: CheckInEngine?
    private var window: PetOverlayPanel?
    private var movement: PetMovementEngine?
    private var timer: Timer?
    private var onTap: (() -> Void)?

    private var stateSubscription: AnyCancellable?
    private var toggleSubscription: AnyCancellable?

    private var lastKnownState: CheckInState?
    private var lastRawLine: String?
    private var bubbleText: String?
    private var bubbleDismissWorkItem: DispatchWorkItem?
    private var dragStartOrigin: CGPoint?

    private enum Keys {
        static let manualX = "petManualPositionX"
        static let manualY = "petManualPositionY"
    }

    init(appState: AppState, engine: CheckInEngine, onTap: @escaping () -> Void) {
        self.onTap = onTap
        self.engine = engine
        model.kind = .deadpool

        stateSubscription = engine.$state.sink { [weak self] state in
            self?.handle(newState: state)
        }
        toggleSubscription = appState.$enableDesktopPet.sink { [weak self] enabled in
            enabled ? self?.install() : self?.uninstall()
        }
        if appState.enableDesktopPet {
            install()
        }
    }

    /// Point just above the character's head, in screen coordinates — used
    /// by ChatWindowController to anchor the chat popup near him.
    var currentScreenPosition: CGPoint {
        guard let window else { return .zero }
        return CGPoint(x: window.frame.midX, y: window.frame.minY + Self.characterHeight + 8)
    }

    private func handle(newState: CheckInState) {
        let previous = lastKnownState
        model.state = newState
        applySpeed(for: newState)

        if let previous, previous != newState {
            // A real transition happened — resume walking if a drag had
            // paused things, and let the character react.
            movement?.isPaused = false
            movement?.resume()
            fireLine(for: newState)
        }
        lastKnownState = newState
    }

    private func fireLine(for state: CheckInState) {
        guard let line = DeadpoolLines.pick(for: state, excluding: lastRawLine) else { return }
        lastRawLine = line
        if state == .away {
            let minutes = Int((engine?.idleSeconds ?? 0) / 60)
            showLine(DeadpoolLines.resolveAway(line, minutes: minutes))
        } else {
            showLine(line)
        }
    }

    private func showLine(_ text: String) {
        bubbleText = text
        bubbleDismissWorkItem?.cancel()
        let dismiss = DispatchWorkItem { [weak self] in
            self?.bubbleText = nil
            self?.render()
        }
        bubbleDismissWorkItem = dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: dismiss)
        render()
    }

    private func install() {
        guard window == nil else { return }
        let bounds = screenBounds()
        let defaults = UserDefaults.standard
        let hasSavedPosition = defaults.object(forKey: Keys.manualX) != nil && defaults.object(forKey: Keys.manualY) != nil

        // `start` is (center-x, bottom-y) — same convention `tick()` uses to
        // place the window from the movement engine's position.
        let start: CGPoint = hasSavedPosition
            ? CGPoint(x: defaults.double(forKey: Keys.manualX), y: defaults.double(forKey: Keys.manualY))
            : CGPoint(x: bounds.maxX, y: bounds.minY) // default: bottom-right

        let newMovement = PetMovementEngine(startingAt: start, bounds: bounds)
        newMovement.isPaused = hasSavedPosition
        movement = newMovement

        let hosting = NSHostingView(rootView: makeContent())
        hosting.frame = NSRect(origin: .zero, size: Self.size)

        let windowOrigin = CGPoint(x: start.x - Self.size.width / 2, y: start.y)
        let panel = PetOverlayPanel(
            contentRect: NSRect(origin: windowOrigin, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = false
        panel.contentView = hosting
        panel.orderFrontRegardless()
        window = panel

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }

        showLine(DeadpoolLines.greeting)
    }

    private func uninstall() {
        timer?.invalidate()
        timer = nil
        bubbleDismissWorkItem?.cancel()
        bubbleDismissWorkItem = nil
        bubbleText = nil
        dragStartOrigin = nil
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

    private func handleDragChanged(_ translation: CGSize) {
        guard let window else { return }
        if dragStartOrigin == nil {
            dragStartOrigin = window.frame.origin
            movement?.isPaused = true
        }
        guard let start = dragStartOrigin else { return }
        window.setFrameOrigin(CGPoint(x: start.x + translation.width, y: start.y - translation.height))
    }

    private func handleDragEnded() {
        dragStartOrigin = nil
        guard let window else { return }
        let center = CGPoint(x: window.frame.midX, y: window.frame.minY)
        movement?.pin(at: center)
        UserDefaults.standard.set(Double(center.x), forKey: Keys.manualX)
        UserDefaults.standard.set(Double(center.y), forKey: Keys.manualY)
    }

    private func tick() {
        guard let movement, let window else { return }
        movement.updateBounds(screenBounds())
        movement.tick(dt: 1.0 / 30.0)
        model.animPhase += 1

        if dragStartOrigin == nil {
            var origin = window.frame.origin
            origin.x = movement.position.x - Self.size.width / 2
            origin.y = movement.position.y
            window.setFrameOrigin(origin)
        }

        render()
    }

    private func render() {
        guard let window else { return }
        (window.contentView as? NSHostingView<PetOverlayContentView>)?.rootView = makeContent()
    }

    private func makeContent() -> PetOverlayContentView {
        PetOverlayContentView(
            model: model,
            facingRight: movement?.facingRight ?? true,
            isWalking: movement?.isWalking ?? false,
            bubbleText: bubbleText,
            onTap: { [weak self] in self?.onTap?() },
            onDragChanged: { [weak self] translation in self?.handleDragChanged(translation) },
            onDragEnded: { [weak self] in self?.handleDragEnded() }
        )
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
