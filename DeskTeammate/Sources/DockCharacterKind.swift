enum DockCharacterKind: String, CaseIterable, Identifiable {
    case robot
    case buddy
    case deadpool

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .robot: return "Robot"
        case .buddy: return "Buddy"
        case .deadpool: return "Deadpool"
        }
    }
}
