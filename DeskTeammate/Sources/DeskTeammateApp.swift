import SwiftUI

@main
struct DeskTeammateApp: App {
    @StateObject private var state = AppState()
    @StateObject private var engine: CheckInEngine
    @StateObject private var dockCharacter: DockCharacterController

    init() {
        let state = AppState()
        let engine = CheckInEngine(appState: state)
        _state = StateObject(wrappedValue: state)
        _engine = StateObject(wrappedValue: engine)
        _dockCharacter = StateObject(wrappedValue: DockCharacterController(appState: state, engine: engine))
        LocalNotifier.requestAuthorizationIfNeeded()
    }

    var body: some Scene {
        MenuBarExtra("Desk Teammate", systemImage: "figure.wave") {
            ContentView()
                .environmentObject(state)
                .environmentObject(engine)
        }
        .menuBarExtraStyle(.window)
    }
}
