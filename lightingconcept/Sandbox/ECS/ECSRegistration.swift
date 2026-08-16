import RealityKit

/// Satu pintu registrasi untuk seluruh custom ECS RealityKit.
///
/// RealityKit harus mengenal custom `Component` dan `System` sebelum scene pertama
/// dibuat. Karena itu `registerAll()` dipanggil dari app startup, sebelum
/// `ContentView` membuat `ARContainerView` dan `ARView`.
enum ECSRegistration {
    private static var hasRegistered = false

    static func registerAll() {
        guard !hasRegistered else { return }
        hasRegistered = true

        SceneObjectComponent.registerComponent()
        SceneLightComponent.registerComponent()
        CollisionObstacleComponent.registerComponent()

        SceneObjectSystem.registerSystem()
        SceneLightSystem.registerSystem()
        CollisionSystem.registerSystem()
    }
}
