import RealityKit
import UIKit

/// Menggambar overlay edukasi untuk arah cahaya, light rays, ground projection,
/// dan projection lines. Entity yang dibuat di sini memakai material unlit dan
/// tidak ikut cast/receive shadow supaya tidak mengganggu simulasi cahaya utama.
final class ProjectionLineRenderer {
    private let root = Entity()
    private var lineEntities: [ModelEntity] = []
    private let maximumRayDistance = ShadowGeometryCalculator.maximumProjectionDistance
    // Renderer ditempel ke anchor lokal, sementara rumus dihitung di world coordinate.
    // Matrix ini mengubah hasil hitungan world -> coordinate root renderer.
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
        lineEntities.forEach { $0.removeFromParent() }
        lineEntities.removeAll()
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
        clear()
        self.worldToRenderTransform = worldToRenderTransform

        // Semua basis arah dinormalisasi agar panjang vector tidak memengaruhi rumus.
        // Yang penting hanya arahnya: forward = arah cahaya, right/up = lebar cone.
        let direction = simd_normalize(lightDirection)
        let right = simd_normalize(lightRight)
        let up = simd_normalize(lightUp)

        if toggles.showLightDirection {
            // Panah kuning menunjukkan arah utama lampu dari orientasi light source,
            // bukan arah otomatis menuju object.
            let end = rayEnd(
                from: lightPosition,
                direction: direction,
                groundY: groundY,
                surfaceIntersection: surfaceIntersection
            )
            addArrow(from: lightPosition, to: end, color: .systemYellow, radius: 0.0032)
        }

        if toggles.showLightRays {
            // Garis oranye adalah beberapa sample ray dalam cone/frustum cahaya.
            // Semakin besar beam spread, semakin jauh ray menyebar dari forward vector.
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
                addLine(from: lightPosition, to: end, color: .systemOrange, radius: 0.0018)
            }
        }

        if toggles.showGroundProjection,
           let groundDirection = ShadowGeometryCalculator.groundShadowDirection(lightDirection: direction) {
            // Panah biru menggambarkan arah bayangan di ground: proyeksi horizontal
            // dari arah datang cahaya. Komponen tinggi tidak dipakai di panah ini.
            let objectGroundPosition = transformPoint(SIMD3<Float>(0, -objectDimensions.y / 2, 0), by: objectTransform)
            let start = SIMD3<Float>(objectGroundPosition.x, groundY + 0.018, objectGroundPosition.z)
            addArrow(from: start, to: start + groundDirection * 0.32, color: .systemBlue, radius: 0.003)
        }

        if toggles.showProjectionLines {
            // Garis ungu dimulai dari titik penting object lalu diteruskan searah cahaya.
            // Ini berbeda dari "garis dari lampu ke vertex"; yang dicari adalah batas
            // bayangan setelah cahaya mengenai/terhalang object.
            let vertices = representativeLocalPoints(
                for: object,
                dimensions: objectDimensions,
                objectTransform: objectTransform,
                lightDirection: direction
            )
            for localVertex in vertices {
                // Local vertex harus diubah ke world coordinate sebelum ray-plane intersection.
                // worldVertex4 = objectTransform * SIMD4(localVertex, 1)
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
        // Sample 2D ini mewakili titik-titik dalam penampang cone:
        // tengah, kiri/kanan, atas/bawah, dan empat diagonal.
        let samples: [SIMD2<Float>] = [
            SIMD2<Float>(0, 0),
            SIMD2<Float>(1, 0),
            SIMD2<Float>(-1, 0),
            SIMD2<Float>(0, 1),
            SIMD2<Float>(0, -1),
            SIMD2<Float>(0.7, 0.7),
            SIMD2<Float>(-0.7, 0.7),
            SIMD2<Float>(0.7, -0.7),
            SIMD2<Float>(-0.7, -0.7)
        ]

        // Frustum sederhana:
        // rayDirection = normalize(forward + right * xSpread + up * ySpread)
        //
        // `tan(angle)` mengubah sudut cone menjadi offset horizontal/vertical.
        // Focused menghasilkan offset kecil, spread menghasilkan offset besar.
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
        // Prioritas pertama: jika ada scene reconstruction/LiDAR, ray berhenti di mesh nyata.
        if let surfaceHit = surfaceIntersection?(origin, normalizedDirection, maximumRayDistance) {
            return surfaceHit
        }
        // Fallback: ray berhenti saat memotong bidang ground datar.
        if let groundHit = ShadowGeometryCalculator.rayPlaneIntersection(
            rayOrigin: origin,
            rayDirection: normalizedDirection,
            planeY: groundY
        ) {
            return groundHit
        }
        // Jika tidak mengenai apa pun, ray tetap digambar sampai batas jarak maksimum.
        return origin + normalizedDirection * maximumRayDistance
    }

    private func representativeLocalPoints(
        for object: ObjectConfiguration,
        dimensions: SIMD3<Float>,
        objectTransform: simd_float4x4,
        lightDirection: SIMD3<Float>
    ) -> [SIMD3<Float>] {
        if object.importedModel != nil {
            // Custom/imported mesh bisa punya vertex sangat banyak. Bounding box corners
            // dipakai sebagai representasi ringan agar overlay tetap terbaca dan hemat performa.
            return boundingBoxCorners(dimensions: dimensions)
        }

        switch object.type {
        case .cube, .cuboid:
            // Bentuk bersudut jelas: cukup gunakan corner bounding box.
            return boundingBoxCorners(dimensions: dimensions)
        case .sphere, .hemisphere:
            // Bentuk lengkung: ambil beberapa titik silhouette terhadap arah cahaya.
            return sphereSamplePoints(dimensions: dimensions, objectTransform: objectTransform, lightDirection: lightDirection)
        case .cylinder:
            // Cylinder: ambil titik penting di lingkaran atas/bawah yang relevan dengan arah cahaya.
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
        // Corner local object: kombinasi min/max dari X, Y, Z.
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
        // Silhouette sphere berada pada bidang yang tegak lurus arah cahaya.
        // Dua basis perpendicular menghasilkan sample di tepi visual sphere.
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
        // `side` adalah arah tangent lingkaran cylinder yang tegak lurus arah cahaya horizontal.
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
        // Untuk cone, titik apex dan beberapa titik base sudah cukup menjelaskan batas shadow.
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
        // Membuat dua vector yang tegak lurus terhadap direction.
        // Dipakai untuk mengambil sample silhouette sphere/hemisphere.
        let fallback = abs(direction.y) < 0.9 ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(1, 0, 0)
        let first = simd_normalize(simd_cross(direction, fallback))
        let second = simd_normalize(simd_cross(direction, first))
        return (first, second)
    }

    private func localVector(_ vector: SIMD3<Float>, objectTransform: simd_float4x4) -> SIMD3<Float> {
        // Vector memakai w = 0 supaya hanya rotasi/scale yang berpengaruh.
        // Translasi object tidak boleh mengubah arah vector.
        let inverse = simd_inverse(objectTransform)
        let local = inverse * SIMD4<Float>(vector.x, vector.y, vector.z, 0)
        return simd_normalize(SIMD3<Float>(local.x, local.y, local.z))
    }

    private func transformPoint(_ point: SIMD3<Float>, by transform: simd_float4x4) -> SIMD3<Float> {
        // Point memakai w = 1 supaya rotasi, scale, dan translasi semuanya ikut.
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
        let cone = ModelEntity(mesh: .generateCone(height: 0.024, radius: radius * 3), materials: [UnlitMaterial(color: color)])
        cone.position = renderEnd
        cone.orientation = orientationForCylinder(from: SIMD3<Float>(0, 1, 0), to: direction)
        disableShadows(for: cone)
        root.addChild(cone)
        lineEntities.append(cone)
    }

    private func addLine(from start: SIMD3<Float>, to end: SIMD3<Float>, color: UIColor, radius: Float) {
        // Rumus dihitung di world coordinate, tapi entity garis adalah child dari anchor.
        // Karena itu posisi start/end dikonversi dulu ke coordinate renderer.
        let renderStart = transformPoint(start, by: worldToRenderTransform)
        let renderEnd = transformPoint(end, by: worldToRenderTransform)
        let vector = renderEnd - renderStart
        let length = simd_length(vector)
        guard length > 0.002, length.isFinite else { return }

        let entity = ModelEntity(mesh: .generateCylinder(height: length, radius: radius), materials: [UnlitMaterial(color: color)])
        entity.position = (renderStart + renderEnd) / 2
        entity.orientation = orientationForCylinder(from: SIMD3<Float>(0, 1, 0), to: simd_normalize(vector))
        disableShadows(for: entity)
        root.addChild(entity)
        lineEntities.append(entity)
    }

    private func addPoint(at position: SIMD3<Float>, color: UIColor) {
        let point = ModelEntity(mesh: .generateSphere(radius: 0.01), materials: [UnlitMaterial(color: color)])
        point.position = transformPoint(position, by: worldToRenderTransform)
        disableShadows(for: point)
        root.addChild(point)
        lineEntities.append(point)
    }

    private func disableShadows(for entity: ModelEntity) {
        entity.components.set(DynamicLightShadowComponent(castsShadow: false))
        entity.components.set(GroundingShadowComponent(castsShadow: false, receivesShadow: false))
    }

    private func orientationForCylinder(from: SIMD3<Float>, to: SIMD3<Float>) -> simd_quatf {
        // Cylinder default berdiri di sumbu Y. Quaternion ini memutar cylinder agar sejajar vector.
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
