enum LearningObjectType: String, CaseIterable, Identifiable {
    case cube = "Cube"
    case sphere = "Sphere"
    case cuboid = "Cuboid"
    case cylinder = "Cylinder"
    case cone = "Cone"
    case hemisphere = "Hemisphere"
    case squarePyramid = "Square Pyramid"
    case triangularPyramid = "Triangular Pyramid"

    var id: String { rawValue }

    var supportsYawRotation: Bool {
        switch self {
        case .sphere, .hemisphere, .cylinder, .cone:
            false
        case .cube, .cuboid, .squarePyramid, .triangularPyramid:
            true
        }
    }
}
