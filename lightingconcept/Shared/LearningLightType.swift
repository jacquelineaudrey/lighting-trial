enum LearningLightType: String, CaseIterable, Identifiable {
    case point = "Point"
    case spot = "Spot"

    var id: String { rawValue }
}
