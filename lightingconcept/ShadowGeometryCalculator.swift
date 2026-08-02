import simd

/// Pure, side-effect-free geometry helpers behind the educational shadow
/// overlays. Kept separate from RealityKit entities so it stays unit
/// testable (see ShadowGeometryCalculatorTests).
enum ShadowGeometryCalculator {
    /// Projection lines/lengths are clamped to this so a near-grazing light
    /// angle doesn't draw a shadow that stretches across the whole room.
    static let maximumProjectionDistance: Float = 1.5

    /// Intersects a ray with the horizontal ground plane (y = planeY).
    /// Returns nil if the ray is parallel to the plane or points away from it.
    static func rayPlaneIntersection(
        rayOrigin: SIMD3<Float>,
        rayDirection: SIMD3<Float>,
        planeY: Float = 0
    ) -> SIMD3<Float>? {
        guard abs(rayDirection.y) > 0.0001 else { return nil }
        let t = (planeY - rayOrigin.y) / rayDirection.y
        guard t > 0, t.isFinite, t <= maximumProjectionDistance else { return nil }
        return rayOrigin + rayDirection * t
    }

    /// Horizontal (ground-plane) unit vector pointing from the light,
    /// through the object, and onward — i.e. the direction the cast shadow
    /// extends. Nil if the light sits directly above the object.
    static func groundShadowDirection(
        lightPosition: SIMD3<Float>,
        objectPosition: SIMD3<Float>
    ) -> SIMD3<Float>? {
        let horizontal = SIMD3<Float>(
            objectPosition.x - lightPosition.x,
            0,
            objectPosition.z - lightPosition.z
        )
        let length = simd_length(horizontal)
        guard length > 0.0001 else { return nil }
        return horizontal / length
    }

    /// Compass-style bearing (degrees) of the cast shadow direction.
    static func shadowDirectionDegrees(
        lightPosition: SIMD3<Float>,
        objectPosition: SIMD3<Float>
    ) -> Float? {
        guard let direction = groundShadowDirection(lightPosition: lightPosition, objectPosition: objectPosition) else {
            return nil
        }
        let radians = atan2(direction.x, direction.z)
        return radians * 180 / .pi
    }

    /// Simple similar-triangles approximation of cast shadow length from
    /// light height, object height, and horizontal light-to-object distance.
    static func approximateShadowLength(
        lightPosition: SIMD3<Float>,
        objectGroundPosition: SIMD3<Float>,
        objectHeight: Float
    ) -> Float? {
        let horizontalDistance = simd_length(SIMD3<Float>(
            objectGroundPosition.x - lightPosition.x,
            0,
            objectGroundPosition.z - lightPosition.z
        ))
        let objectTopY = objectGroundPosition.y + objectHeight
        let heightAboveObject = lightPosition.y - objectTopY
        guard heightAboveObject > 0.01 else { return nil }
        let length = (objectHeight * horizontalDistance) / heightAboveObject
        return min(length, maximumProjectionDistance)
    }

    /// Ground intersection points for rays cast from the light through each
    /// of the cube's four top vertices. Used to draw educational projection
    /// lines for the cube object.
    static func cubeProjectionPoints(
        lightPosition: SIMD3<Float>,
        cubeCenter: SIMD3<Float>,
        yawDegrees: Float = 0
    ) -> [SIMD3<Float>] {
        let half = ObjectFactory.cubeSize / 2
        let rotation = simd_quatf(angle: yawDegrees * .pi / 180, axis: SIMD3<Float>(0, 1, 0))
        let localVertices = [
            SIMD3<Float>( half,  half,  half),
            SIMD3<Float>(-half,  half,  half),
            SIMD3<Float>( half,  half, -half),
            SIMD3<Float>(-half,  half, -half),
            SIMD3<Float>( half, -half,  half),
            SIMD3<Float>(-half, -half,  half),
            SIMD3<Float>( half, -half, -half),
            SIMD3<Float>(-half, -half, -half)
        ]

        return localVertices.compactMap { localVertex in
            let vertex = cubeCenter + rotation.act(localVertex)
            let direction = simd_normalize(vertex - lightPosition)
            return rayPlaneIntersection(rayOrigin: lightPosition, rayDirection: direction)
        }
    }
}
