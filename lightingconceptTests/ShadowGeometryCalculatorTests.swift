import Testing
import simd
@testable import lightingconcept

struct ShadowGeometryCalculatorTests {
    @Test func rayPlaneIntersectionFindsGroundHit() {
        let hit = ShadowGeometryCalculator.rayPlaneIntersection(
            rayOrigin: SIMD3<Float>(0, 1, 0),
            rayDirection: simd_normalize(SIMD3<Float>(0.25, -1, 0.25))
        )

        #expect(hit != nil)
        #expect(abs((hit?.y ?? 1) - 0) < 0.0001)
    }

    @Test func rayPlaneIntersectionRejectsParallelRay() {
        let hit = ShadowGeometryCalculator.rayPlaneIntersection(
            rayOrigin: SIMD3<Float>(0, 1, 0),
            rayDirection: SIMD3<Float>(1, 0, 0)
        )

        #expect(hit == nil)
    }

    @Test func groundShadowDirectionExtendsAwayFromLight() {
        let direction = ShadowGeometryCalculator.groundShadowDirection(
            lightPosition: SIMD3<Float>(-1, 1, 0),
            objectPosition: SIMD3<Float>(0, 0, 0)
        )

        #expect(direction != nil)
        #expect((direction?.x ?? 0) > 0)
        #expect(abs(direction?.y ?? 1) < 0.0001)
    }

    @Test func approximateShadowLengthUsesLightHeightAndDistance() {
        let length = ShadowGeometryCalculator.approximateShadowLength(
            lightPosition: SIMD3<Float>(0.4, 0.6, 0),
            objectGroundPosition: SIMD3<Float>(0, 0, 0),
            objectHeight: 0.12
        )

        #expect(length != nil)
        #expect((length ?? 0) > 0)
        #expect((length ?? 0) < ShadowGeometryCalculator.maximumProjectionDistance)
    }

    @Test func cubeProjectionProducesValidGroundPoints() {
        let points = ShadowGeometryCalculator.cubeProjectionPoints(
            lightPosition: SIMD3<Float>(-0.3, 0.5, 0.2),
            cubeCenter: SIMD3<Float>(0, ObjectFactory.cubeSize / 2, 0)
        )

        #expect(!points.isEmpty)
        #expect(points.allSatisfy { abs($0.y) < 0.0001 })
    }

    @Test func spotlightAimPointsAtObjectCenter() {
        let lightPosition = SIMD3<Float>(-0.38, 0.55, 0.46)
        let objectCenter = SIMD3<Float>(0, 0.1125, 0)
        let angles = SceneLightEntityFactory.aimingAngles(
            from: lightPosition,
            to: objectCenter
        )

        #expect(angles != nil)
        guard let angles else { return }

        let actualDirection = SceneLightEntityFactory.forwardVector(
            yawDegrees: angles.yawDegrees,
            pitchDegrees: angles.pitchDegrees
        )
        let expectedDirection = simd_normalize(objectCenter - lightPosition)

        #expect(simd_dot(actualDirection, expectedDirection) > 0.9999)
    }
}
