enum DockCharacterKind: String, CaseIterable, Identifiable {
    case robot
    case buddy

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .robot: return "Robot"
        case .buddy: return "Buddy"
        }
    }
}
