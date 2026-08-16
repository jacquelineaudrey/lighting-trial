import RealityKit

enum Level3ECSRegistration {
    private static var hasRegistered = false

    static func registerAll() {
        guard !hasRegistered else { return }
        hasRegistered = true
        Level3ShadowPresentationComponent.registerComponent()
        Level3ShadowPresentationSystem.registerSystem()
    }
}
