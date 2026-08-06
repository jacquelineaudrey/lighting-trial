enum BeamSpreadPreset: String, CaseIterable, Identifiable {
    case focused = "Focused"
    case medium = "Medium"
    case spread = "Spread"

    var id: String { rawValue }

    var innerAngle: Float {
        switch self {
        case .focused: 10
        case .medium: 28
        case .spread: 52
        }
    }

    var outerAngle: Float {
        switch self {
        case .focused: 24
        case .medium: 54
        case .spread: 88
        }
    }
}
