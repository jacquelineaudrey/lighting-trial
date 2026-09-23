import RealityKit

/// Moves only entities carrying `Level6DeviceFollowComponent`.
/// All per-frame spatial calculations remain inside the RealityKit ECS domain.
final class Level6DeviceFollowSystem: System {
    private static let query = EntityQuery(
        where: .has(Level6DeviceFollowComponent.self)
    )

    required init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        for entity in context.entities(
            matching: Self.query,
            updatingSystemWhen: .rendering
        ) {
            guard let follow = entity.components[Level6DeviceFollowComponent.self],
                  follow.isActive else { continue }

            let worldDelta = follow.currentCameraWorldPosition
                - follow.startCameraWorldPosition
            let localDelta = localVector(worldDelta, relativeTo: entity.parent)
            let unclampedPosition = follow.startLightLocalPosition + localDelta
            let nextPosition = SIMD3<Float>(
                clamped(
                    unclampedPosition.x,
                    follow.minimumLocalPosition.x,
                    follow.maximumLocalPosition.x
                ),
                clamped(
                    unclampedPosition.y,
                    follow.minimumLocalPosition.y,
                    follow.maximumLocalPosition.y
                ),
                clamped(
                    unclampedPosition.z,
                    follow.minimumLocalPosition.z,
                    follow.maximumLocalPosition.z
                )
            )

            entity.position = nextPosition
            updateLightDirection(
                on: entity,
                from: nextPosition,
                toward: follow.aimTargetLocalPosition
            )
            updateSceneLightState(on: entity, position: nextPosition)

        }
    }

    private func localVector(
        _ worldVector: SIMD3<Float>,
        relativeTo parent: Entity?
    ) -> SIMD3<Float> {
        guard let parent else { return worldVector }
        let converted = simd_inverse(parent.transformMatrix(relativeTo: nil))
            * SIMD4<Float>(worldVector.x, worldVector.y, worldVector.z, 0)
        return SIMD3<Float>(converted.x, converted.y, converted.z)
    }

    private func updateLightDirection(
        on entity: Entity,
        from lightPosition: SIMD3<Float>,
        toward targetPosition: SIMD3<Float>
    ) {
        guard let emitter = entity.children.first(where: { $0.name == "Light Emitter" }),
              let angles = SceneLightSystem.aimingAngles(
                from: lightPosition,
                to: targetPosition
              ) else { return }
        emitter.orientation = SceneLightSystem.orientation(
            yawDegrees: angles.yawDegrees,
            pitchDegrees: angles.pitchDegrees
        )
    }

    private func updateSceneLightState(
        on entity: Entity,
        position: SIMD3<Float>
    ) {
        guard var sceneLight = entity.components[SceneLightComponent.self] else { return }
        sceneLight.configuration.position = position
        if let angles = SceneLightSystem.aimingAngles(
            from: position,
            to: entity.components[Level6DeviceFollowComponent.self]?.aimTargetLocalPosition ?? .zero
        ) {
            sceneLight.configuration.yawDegrees = angles.yawDegrees
            sceneLight.configuration.pitchDegrees = angles.pitchDegrees
        }
        entity.components.set(sceneLight)
    }
}
