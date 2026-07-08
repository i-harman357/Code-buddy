import SwiftUI

@main
struct DeskTeammateApp: App {
    @StateObject private var state = AppState()
    @StateObject private var engine: CheckInEngine
    @StateObject private var dockCharacter: DockCharacterController
    @StateObject private var petWindow: PetWindowController
    private let chatWindow: ChatWindowController

    init() {
        let state = AppState()
        let engine = CheckInEngine(appState: state)
        let chatWindow = ChatWindowController()
        _state = StateObject(wrappedValue: state)
        _engine = StateObject(wrappedValue: engine)
        _dockCharacter = StateObject(wrappedValue: DockCharacterController(appState: state, engine: engine))
        let petWindow = PetWindowController(appState: state, engine: engine, onTap: {
            chatWindow.toggle()
        })
        chatWindow.anchorProvider = { [weak petWindow] in
            petWindow?.currentScreenPosition ?? CGPoint(x: 400, y: 400)
        }
        _petWindow = StateObject(wrappedValue: petWindow)
        self.chatWindow = chatWindow
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
