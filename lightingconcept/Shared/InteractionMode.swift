enum InteractionMode: String, CaseIterable, Identifiable {
    case moveObject = "Move Object"
    case moveLight = "Move Light"

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .moveObject:
            return "Object"
        case .moveLight:
            return "Light"
        }
    }
}
