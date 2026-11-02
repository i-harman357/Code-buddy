import AppKit
import SwiftUI
import Combine

/// Owns the NSDockTile custom content view and its redraw timer.
/// Only active while AppState.showDockCharacter is on; otherwise the app
/// stays a pure accessory (no Dock icon at all).
@MainActor
final class DockCharacterController: ObservableObject {
    private let model = DockCharacterModel()
    private var hostingView: NSHostingView<DockCharacterContainerView>?
    private var timer: Timer?

    private var stateSubscription: AnyCancellable?
    private var toggleSubscription: AnyCancellable?
    private var kindSubscription: AnyCancellable?

    init(appState: AppState, engine: CheckInEngine) {
        stateSubscription = engine.$state.sink { [weak self] state in
            self?.model.state = state
            self?.updateTimerCadence(for: state)
        }
        toggleSubscription = appState.$showDockCharacter.dropFirst().sink { [weak self] show in
            show ? self?.install() : self?.uninstall()
        }
        kindSubscription = appState.$dockCharacterKind.sink { [weak self] kind in
            self?.model.kind = kind
        }
        model.kind = appState.dockCharacterKind
        if appState.showDockCharacter {
            // Defer past App init: calling NSApp.dockTile.display() here would
            // re-enter SwiftUI's AttributeGraph while it's still constructing
            // the App's scene graph, which aborts with an AG precondition
            // failure. Waiting a tick lets the graph settle first.
            DispatchQueue.main.async { [weak self] in
                self?.install()
            }
        }
    }

    private func install() {
        NSApp.setActivationPolicy(.regular)

        let size = NSApp.dockTile.size
        let hosting = NSHostingView(rootView: DockCharacterContainerView(model: model))
        hosting.frame = NSRect(origin: .zero, size: size)
        NSApp.dockTile.contentView = hosting
        hostingView = hosting
        NSApp.dockTile.display()

        updateTimerCadence(for: model.state)
    }

    private func uninstall() {
        timer?.invalidate()
        timer = nil
        NSApp.dockTile.contentView = nil
        hostingView = nil
        NSApp.setActivationPolicy(.accessory)
    }

    /// 15fps while animating (ACTIVE/STALLING), ~1fps otherwise (FLOW/AWAY/STOPPED).
    private func updateTimerCadence(for state: CheckInState) {
        guard hostingView != nil else { return }
        let animating = state == .active || state == .stalling
        let interval: TimeInterval = animating ? (1.0 / 15.0) : 1.0

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        model.animPhase += 1
        NSApp.dockTile.display()
    }
}
