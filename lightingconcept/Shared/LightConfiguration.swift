import Foundation
import SwiftUI

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
