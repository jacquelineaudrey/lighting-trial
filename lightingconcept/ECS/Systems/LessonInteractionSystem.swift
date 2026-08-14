import RealityKit

final class LessonInteractionSystem: System {
    private static let query = EntityQuery(where: .has(LessonInteractionComponent.self))

    required init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        // Interaction state is intentionally data-only. SwiftUI gestures update
        // the ViewModel, which writes ECS components through the AR bridge.
        for _ in context.scene.performQuery(Self.query) { }
    }
}
