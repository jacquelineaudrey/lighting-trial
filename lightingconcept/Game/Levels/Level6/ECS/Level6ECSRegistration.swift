import RealityKit

enum Level6ECSRegistration {
    private static var hasRegistered = false

    static func registerAll() {
        guard !hasRegistered else { return }
        hasRegistered = true
        Level6DeviceFollowComponent.registerComponent()
        Level6LightControlComponent.registerComponent()
        Level6DeviceFollowSystem.registerSystem()
        Level6LightControlSystem.registerSystem()
    }
}
