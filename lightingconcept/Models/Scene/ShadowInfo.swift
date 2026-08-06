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
