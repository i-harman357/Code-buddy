import Combine

@MainActor
final class DockCharacterModel: ObservableObject {
    @Published var state: CheckInState = .stopped
    @Published var animPhase: Double = 0
    @Published var kind: DockCharacterKind = .robot
}
