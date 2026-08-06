enum ShadowConcept: String, CaseIterable, Identifiable {
    case lightSide = "Light Side"
    case shadowSide = "Shadow Side"
    case terminator = "Terminator"
    case coreShadow = "Core Shadow"
    case castShadow = "Cast Shadow"
    case contactShadow = "Contact Shadow"
    case highlight = "Highlight"
    case reflectedLight = "Reflected Light"

    var id: String { rawValue }

    var explanation: String {
        switch self {
        case .lightSide:
            "The side of the form that faces the light most directly."
        case .shadowSide:
            "The side turned away from the light, receiving less direct light."
        case .terminator:
            "The boundary where the form turns from facing the light to facing away."
        case .coreShadow:
            "The darkest broad area on the object where the surface turns away from direct light."
        case .castShadow:
            "The shadow projected onto another surface because the object blocks the light."
        case .contactShadow:
            "The darkest area where the object touches the surface because very little light enters the gap."
        case .highlight:
            "The small bright region where the surface faces the light most directly."
        case .reflectedLight:
            "A softer light area inside the shadow side caused by nearby surfaces bouncing light back."
        }
    }
}
