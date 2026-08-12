import Foundation

struct SceneUpdateSignature: Equatable {
    var objects: [ObjectConfiguration]
    var selectedObjectID: UUID
    var selectedTexture: MaterialTexture
    var lights: [LightConfiguration]
    var selectedLightID: UUID
    var showLightDirection: Bool
    var showLightRays: Bool
    var showProjectionLines: Bool
    var showGroundProjection: Bool
    var showShadowLabels: Bool
    var showShadowInformation: Bool
}
