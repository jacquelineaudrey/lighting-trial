import Foundation
import SwiftUI
import RealityKit

enum LearningObjectType: String, CaseIterable, Identifiable {
    case cube = "Cube"
    case sphere = "Sphere"
    case cylinder = "Cylinder"
    case cone = "Cone"

    var id: String { rawValue }
}

enum LearningLightType: String, CaseIterable, Identifiable {
    case point = "Point"
    case spot = "Spot"

    var id: String { rawValue }
}

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

enum SurfaceDetectionState {
    case scanning
    case found
    case placed
}

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

struct LightConfiguration: Identifiable, Equatable {
    let id: UUID
    var name: String
    var type: LearningLightType
    var color: Color
    var intensity: Float
    var position: SIMD3<Float>
    var yawDegrees: Float
    var pitchDegrees: Float
    var beamSpread: BeamSpreadPreset

    static func defaultLight(index: Int = 1) -> LightConfiguration {
        LightConfiguration(
            id: UUID(),
            name: "Light \(index)",
            type: .spot,
            color: Color(red: 1.0, green: 0.86, blue: 0.62),
            intensity: 3600,
            position: SIMD3<Float>(-0.16, 0.32, 0.14),
            yawDegrees: 0,
            pitchDegrees: -35,
            beamSpread: .spread
        )
    }
}

struct ShadowInfo: Equatable {
    var lightType: String = "Spot"
    var intensity: Float = 0
    var lightHeight: Float = 0
    var yawDegrees: Float = 0
    var pitchDegrees: Float = 0
    var beamSpread: String = "Medium"
    var shadowDirectionDegrees: Float?
    var shadowLength: Float?
}

struct SceneUpdateSignature: Equatable {
    var objectType: LearningObjectType
    var selectedTexture: MaterialTexture
    var objectScale: Float
    var objectYawDegrees: Float
    var lights: [LightConfiguration]
    var selectedLightID: UUID
    var showLightDirection: Bool
    var showLightRays: Bool
    var showProjectionLines: Bool
    var showGroundProjection: Bool
    var showShadowLabels: Bool
    var showShadowInformation: Bool
}
