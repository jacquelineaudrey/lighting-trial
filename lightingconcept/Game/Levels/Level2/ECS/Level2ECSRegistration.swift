import RealityKit

enum Level2ECSRegistration {
    private static var hasRegistered = false

    static func registerAll() {
        guard !hasRegistered else { return }
        hasRegistered = true
        Level2LightControlComponent.registerComponent()
        Level2LightControlSystem.registerSystem()
    }
}
