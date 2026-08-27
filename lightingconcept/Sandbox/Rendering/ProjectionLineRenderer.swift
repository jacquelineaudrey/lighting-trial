import RealityKit
import UIKit

/// Menggambar overlay edukasi untuk arah cahaya, light rays, ground projection,
/// dan projection lines. Entity yang dibuat di sini memakai material unlit dan
/// tidak ikut cast/receive shadow supaya tidak mengganggu simulasi cahaya utama.
final class ProjectionLineRenderer {
    private let root = Entity()

    // Shared unit meshes for zero-allocation rendering
    private static let unitCylinderMesh: MeshResource = .generateCylinder(height: 1.0, radius: 1.0)
    private static let unitConeMesh: MeshResource = .generateCone(height: 1.0, radius: 1.0)
    private static let unitSphereMesh: MeshResource = .generateSphere(radius: 1.0)

    private var lineEntities: [ModelEntity] = []
    private var coneEntities: [ModelEntity] = []
    private var pointEntities: [ModelEntity] = []

    // `ensureMaterial` used to compare against the color read back out of the
    // entity's already-applied material. RealityKit converts UIColor into its
    // own internal color-space representation when a material is applied, so
    // reading `.tint` back out rarely matches the original value bit-for-bit
    // even when the color never changed — the "skip if unchanged" check was
    // failing almost every time, silently rebuilding the material on nearly
    // every line/arrow/dot on every overlay update. Tracking what we last set
    // ourselves sidesteps that round-trip entirely.
    private var lastMaterialColor: [ObjectIdentifier: UIColor] = [:]

    private var activeLineCount = 0
    private var activeConeCount = 0
    private var activePointCount = 0

    private let maximumRayDistance = ShadowGeometryCalculator.maximumProjectionDistance
    private var worldToRenderTransform = matrix_identity_float4x4

    init() {
        root.name = "Educational overlays"
    }

    func attach(to anchor: AnchorEntity) {
        if root.parent == nil {
            anchor.addChild(root)
        }
    }

    func clear() {
        lineEntities.forEach { $0.isEnabled = false }
        coneEntities.forEach { $0.isEnabled = false }
        pointEntities.forEach { $0.isEnabled = false }
        activeLineCount = 0
        activeConeCount = 0
        activePointCount = 0
    }

    func update(
        object: ObjectConfiguration,
        objectDimensions: SIMD3<Float>,
        objectTransform: simd_float4x4,
        lightPosition: SIMD3<Float>,
        selectedLight: LightConfiguration,
        lightDirection: SIMD3<Float>,
        lightRight: SIMD3<Float>,
        lightUp: SIMD3<Float>,
        groundY: Float,
        worldToRenderTransform: simd_float4x4,
        toggles: OverlayToggles,
        surfaceIntersection: ((SIMD3<Float>, SIMD3<Float>, Float) -> SIMD3<Float>?)? = nil
    ) {
        activeLineCount = 0
        activeConeCount = 0
        activePointCount = 0
        self.worldToRenderTransform = worldToRenderTransform

        // Semua basis arah dinormalisasi agar panjang vector tidak memengaruhi rumus.
        let direction = simd_normalize(lightDirection)
        let right = simd_normalize(lightRight)
        let up = simd_normalize(lightUp)

        if toggles.showLightDirection {
            let end = rayEnd(
                from: lightPosition,
                direction: direction,
                groundY: groundY,
                surfaceIntersection: surfaceIntersection
            )
            addArrow(from: lightPosition, to: end, color: .systemYellow, radius: 0.0032)
        }

        if toggles.showLightRays {
            let intensityRatio = clamped((selectedLight.intensity - 450) / (6_500 - 450), 0, 1)
            let rayRadius = 0.0012 + intensityRatio * 0.0014
            let rayAlpha = CGFloat(0.45 + intensityRatio * 0.55)
            let rayColor = UIColor.systemOrange.withAlphaComponent(rayAlpha)
            for rayDirection in coneRayDirections(
                forward: direction,
                right: right,
                up: up,
                innerAngleDegrees: selectedLight.effectiveInnerAngleDegrees,
                outerAngleDegrees: selectedLight.effectiveOuterAngleDegrees
            ) {
                let end = rayEnd(
                    from: lightPosition,
                    direction: rayDirection,
                    groundY: groundY,
                    surfaceIntersection: surfaceIntersection
                )
                addLine(from: lightPosition, to: end, color: rayColor, radius: rayRadius)
            }
        }

        if toggles.showGroundProjection,
           let groundDirection = ShadowGeometryCalculator.groundShadowDirection(lightDirection: direction) {
            let objectGroundPosition = transformPoint(SIMD3<Float>(0, -objectDimensions.y / 2, 0), by: objectTransform)
            let start = SIMD3<Float>(objectGroundPosition.x, groundY + 0.018, objectGroundPosition.z)
            addArrow(from: start, to: start + groundDirection * 0.32, color: .systemBlue, radius: 0.003)
        }

        if toggles.showProjectionLines {
            let vertices = representativeLocalPoints(
                for: object,
                dimensions: objectDimensions,
                objectTransform: objectTransform,
                lightDirection: direction
            )
            for localVertex in vertices {
                let worldVertex = transformPoint(localVertex, by: objectTransform)
                guard let projected = ShadowGeometryCalculator.projectPointAlongLightDirection(
                    vertexPosition: worldVertex,
                    lightDirection: direction,
                    planeY: groundY
                ) else {
                    continue
                }
                let raisedProjection = projected + SIMD3<Float>(0, 0.018, 0)
                addLine(from: worldVertex, to: raisedProjection, color: .systemPurple, radius: 0.0018)
                addPoint(at: projected + SIMD3<Float>(0, 0.024, 0), color: .systemPurple)
            }
        }

        // Hide any remaining unused pooled entities
        for i in activeLineCount..<lineEntities.count { lineEntities[i].isEnabled = false }
        for i in activeConeCount..<coneEntities.count { coneEntities[i].isEnabled = false }
        for i in activePointCount..<pointEntities.count { pointEntities[i].isEnabled = false }
    }

    private func coneRayDirections(
        forward: SIMD3<Float>,
        right: SIMD3<Float>,
        up: SIMD3<Float>,
        innerAngleDegrees: Float,
        outerAngleDegrees: Float
    ) -> [SIMD3<Float>] {
        let horizontalAngle = outerAngleDegrees.degreesToRadians / 2
        let verticalAngle = innerAngleDegrees.degreesToRadians / 2
        let horizontalSpread = tan(horizontalAngle)
        let verticalSpread = tan(verticalAngle)
        let samples: [SIMD2<Float>] = [
            SIMD2<Float>(1, 0),
            SIMD2<Float>(-1, 0),
            SIMD2<Float>(0, 1),
            SIMD2<Float>(0, -1)
        ]

        return samples.map { sample in
            simd_normalize(
                forward
                + right * sample.x * horizontalSpread
                + up * sample.y * verticalSpread
            )
        }
    }

    private func rayEnd(
        from origin: SIMD3<Float>,
        direction: SIMD3<Float>,
        groundY: Float,
        surfaceIntersection: ((SIMD3<Float>, SIMD3<Float>, Float) -> SIMD3<Float>?)?
    ) -> SIMD3<Float> {
        let normalizedDirection = simd_normalize(direction)
        if let groundHit = ShadowGeometryCalculator.rayPlaneIntersection(
            rayOrigin: origin,
            rayDirection: normalizedDirection,
            planeY: groundY
        ) {
            return groundHit
        }
        if let surfaceHit = surfaceIntersection?(origin, normalizedDirection, maximumRayDistance) {
            return surfaceHit
        }
        return origin + normalizedDirection * maximumRayDistance
    }

    private func representativeLocalPoints(
        for object: ObjectConfiguration,
        dimensions: SIMD3<Float>,
        objectTransform: simd_float4x4,
        lightDirection: SIMD3<Float>
    ) -> [SIMD3<Float>] {
        if object.importedModel != nil {
            return boundingBoxCorners(dimensions: dimensions)
        }

        switch object.type {
        case .cube, .cuboid:
            return boundingBoxCorners(dimensions: dimensions)
        case .sphere, .hemisphere:
            return sphereSamplePoints(dimensions: dimensions, objectTransform: objectTransform, lightDirection: lightDirection)
        case .cylinder:
            return cylinderSamplePoints(dimensions: dimensions, objectTransform: objectTransform, lightDirection: lightDirection)
        case .cone:
            return coneSamplePoints(dimensions: dimensions, objectTransform: objectTransform, lightDirection: lightDirection)
        case .squarePyramid:
            return squarePyramidPoints(dimensions: dimensions)
        case .triangularPyramid:
            return triangularPyramidPoints(dimensions: dimensions)
        }
    }

    private func boundingBoxCorners(dimensions: SIMD3<Float>) -> [SIMD3<Float>] {
        let half = dimensions / 2
        return [
            SIMD3<Float>(-half.x, -half.y, -half.z),
            SIMD3<Float>(half.x, -half.y, -half.z),
            SIMD3<Float>(-half.x, -half.y, half.z),
            SIMD3<Float>(half.x, -half.y, half.z),
            SIMD3<Float>(-half.x, half.y, -half.z),
            SIMD3<Float>(half.x, half.y, -half.z),
            SIMD3<Float>(-half.x, half.y, half.z),
            SIMD3<Float>(half.x, half.y, half.z)
        ]
    }

    private func squarePyramidPoints(dimensions: SIMD3<Float>) -> [SIMD3<Float>] {
        let half = dimensions / 2
        return [
            SIMD3<Float>(-half.x, -half.y, -half.z),
            SIMD3<Float>(half.x, -half.y, -half.z),
            SIMD3<Float>(half.x, -half.y, half.z),
            SIMD3<Float>(-half.x, -half.y, half.z),
            SIMD3<Float>(0, half.y, 0)
        ]
    }

    private func triangularPyramidPoints(dimensions: SIMD3<Float>) -> [SIMD3<Float>] {
        let halfHeight = dimensions.y / 2
        let halfWidth = dimensions.x / 2
        let baseDepth = dimensions.z / 2
        return [
            SIMD3<Float>(0, -halfHeight, -baseDepth),
            SIMD3<Float>(-halfWidth, -halfHeight, baseDepth),
            SIMD3<Float>(halfWidth, -halfHeight, baseDepth),
            SIMD3<Float>(0, halfHeight, 0)
        ]
    }

    private func sphereSamplePoints(
        dimensions: SIMD3<Float>,
        objectTransform: simd_float4x4,
        lightDirection: SIMD3<Float>
    ) -> [SIMD3<Float>] {
        let radius = min(dimensions.x, dimensions.y, dimensions.z) / 2
        let localDirection = localVector(lightDirection, objectTransform: objectTransform)
        let basis = perpendicularBasis(to: localDirection)
        return [
            basis.0 * radius,
            -basis.0 * radius,
            basis.1 * radius,
            -basis.1 * radius,
            (basis.0 + basis.1) * (radius * 0.7),
            (-basis.0 + basis.1) * (radius * 0.7)
        ]
    }

    private func cylinderSamplePoints(
        dimensions: SIMD3<Float>,
        objectTransform: simd_float4x4,
        lightDirection: SIMD3<Float>
    ) -> [SIMD3<Float>] {
        let radius = min(dimensions.x, dimensions.z) / 2
        let halfHeight = dimensions.y / 2
        let localDirection = localVector(lightDirection, objectTransform: objectTransform)
        let horizontal = SIMD3<Float>(localDirection.x, 0, localDirection.z)
        let side = simd_length(horizontal) > 0.0001
            ? simd_normalize(SIMD3<Float>(-horizontal.z, 0, horizontal.x))
            : SIMD3<Float>(1, 0, 0)
        let forwardEdge = simd_length(horizontal) > 0.0001 ? simd_normalize(horizontal) : SIMD3<Float>(0, 0, 1)
        return [
            side * radius + SIMD3<Float>(0, halfHeight, 0),
            -side * radius + SIMD3<Float>(0, halfHeight, 0),
            side * radius + SIMD3<Float>(0, -halfHeight, 0),
            -side * radius + SIMD3<Float>(0, -halfHeight, 0),
            forwardEdge * radius + SIMD3<Float>(0, halfHeight, 0),
            forwardEdge * radius + SIMD3<Float>(0, -halfHeight, 0)
        ]
    }

    private func coneSamplePoints(
        dimensions: SIMD3<Float>,
        objectTransform: simd_float4x4,
        lightDirection: SIMD3<Float>
    ) -> [SIMD3<Float>] {
        let radius = min(dimensions.x, dimensions.z) / 2
        let halfHeight = dimensions.y / 2
        let localDirection = localVector(lightDirection, objectTransform: objectTransform)
        let horizontal = SIMD3<Float>(localDirection.x, 0, localDirection.z)
        let side = simd_length(horizontal) > 0.0001
            ? simd_normalize(SIMD3<Float>(-horizontal.z, 0, horizontal.x))
            : SIMD3<Float>(1, 0, 0)
        return [
            SIMD3<Float>(0, halfHeight, 0),
            side * radius + SIMD3<Float>(0, -halfHeight, 0),
            -side * radius + SIMD3<Float>(0, -halfHeight, 0),
            SIMD3<Float>(radius, -halfHeight, 0),
            SIMD3<Float>(-radius, -halfHeight, 0)
        ]
    }

    private func perpendicularBasis(to direction: SIMD3<Float>) -> (SIMD3<Float>, SIMD3<Float>) {
        let fallback = abs(direction.y) < 0.9 ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(1, 0, 0)
        let first = simd_normalize(simd_cross(direction, fallback))
        let second = simd_normalize(simd_cross(direction, first))
        return (first, second)
    }

    private func localVector(_ vector: SIMD3<Float>, objectTransform: simd_float4x4) -> SIMD3<Float> {
        let inverse = simd_inverse(objectTransform)
        let local = inverse * SIMD4<Float>(vector.x, vector.y, vector.z, 0)
        return simd_normalize(SIMD3<Float>(local.x, local.y, local.z))
    }

    private func transformPoint(_ point: SIMD3<Float>, by transform: simd_float4x4) -> SIMD3<Float> {
        let transformed = transform * SIMD4<Float>(point.x, point.y, point.z, 1)
        return SIMD3<Float>(transformed.x, transformed.y, transformed.z)
    }

    private func addArrow(from start: SIMD3<Float>, to end: SIMD3<Float>, color: UIColor, radius: Float) {
        addLine(from: start, to: end, color: color, radius: radius)
        let renderEnd = transformPoint(end, by: worldToRenderTransform)
        let renderStart = transformPoint(start, by: worldToRenderTransform)
        let vector = renderEnd - renderStart
        let length = simd_length(vector)
        guard length > 0.002, length.isFinite else { return }

        let direction = vector / length
        let cone: ModelEntity
        if activeConeCount < coneEntities.count {
            cone = coneEntities[activeConeCount]
            ensureMaterial(for: cone, color: color)
        } else {
            cone = ModelEntity(mesh: Self.unitConeMesh, materials: [UnlitMaterial(color: color)])
            disableShadows(for: cone)
            root.addChild(cone)
            coneEntities.append(cone)
        }
        activeConeCount += 1

        cone.isEnabled = true
        cone.position = renderEnd
        cone.orientation = orientationForCylinder(from: SIMD3<Float>(0, 1, 0), to: direction)
        cone.scale = SIMD3<Float>(radius * 3, 0.024, radius * 3)
    }

    private func addLine(from start: SIMD3<Float>, to end: SIMD3<Float>, color: UIColor, radius: Float) {
        let renderStart = transformPoint(start, by: worldToRenderTransform)
        let renderEnd = transformPoint(end, by: worldToRenderTransform)
        let vector = renderEnd - renderStart
        let length = simd_length(vector)
        guard length > 0.002, length.isFinite else { return }

        let entity: ModelEntity
        if activeLineCount < lineEntities.count {
            entity = lineEntities[activeLineCount]
            ensureMaterial(for: entity, color: color)
        } else {
            entity = ModelEntity(mesh: Self.unitCylinderMesh, materials: [UnlitMaterial(color: color)])
            disableShadows(for: entity)
            root.addChild(entity)
            lineEntities.append(entity)
        }
        activeLineCount += 1

        entity.isEnabled = true
        entity.position = (renderStart + renderEnd) / 2
        entity.orientation = orientationForCylinder(from: SIMD3<Float>(0, 1, 0), to: simd_normalize(vector))
        entity.scale = SIMD3<Float>(radius, length, radius)
    }

    private func addPoint(at position: SIMD3<Float>, color: UIColor) {
        let renderPosition = transformPoint(position, by: worldToRenderTransform)
        let point: ModelEntity
        if activePointCount < pointEntities.count {
            point = pointEntities[activePointCount]
            ensureMaterial(for: point, color: color)
        } else {
            point = ModelEntity(mesh: Self.unitSphereMesh, materials: [UnlitMaterial(color: color)])
            disableShadows(for: point)
            root.addChild(point)
            pointEntities.append(point)
        }
        activePointCount += 1

        point.isEnabled = true
        point.position = renderPosition
        point.scale = SIMD3<Float>(repeating: 0.01)
    }

    private func ensureMaterial(for entity: ModelEntity, color: UIColor) {
        let key = ObjectIdentifier(entity)
        if let current = lastMaterialColor[key], current == color {
            return
        }
        var material = UnlitMaterial()
        material.color = .init(tint: color)
        entity.model?.materials = [material]
        lastMaterialColor[key] = color
    }

    private func disableShadows(for entity: ModelEntity) {
        entity.components.set(DynamicLightShadowComponent(castsShadow: false))
        entity.components.set(GroundingShadowComponent(castsShadow: false, receivesShadow: false))
    }

    private func orientationForCylinder(from: SIMD3<Float>, to: SIMD3<Float>) -> simd_quatf {
        let axis = simd_cross(from, to)
        let dot = simd_dot(from, to)
        if simd_length(axis) < 0.0001 {
            return dot > 0 ? simd_quatf() : simd_quatf(angle: .pi, axis: SIMD3<Float>(1, 0, 0))
        }
        return simd_quatf(angle: acos(clamped(dot, -1, 1)), axis: simd_normalize(axis))
    }
}

struct OverlayToggles {
    var showLightDirection: Bool
    var showLightRays: Bool
    var showProjectionLines: Bool
    var showGroundProjection: Bool
}
