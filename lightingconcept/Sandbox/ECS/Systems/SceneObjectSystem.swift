import Foundation
import RealityKit
import UIKit

/// System RealityKit untuk entity yang punya `SceneObjectComponent`.
///
/// Entity object adalah `RealityKit.Entity` root yang tampil di AR. Data object
/// disimpan di `SceneObjectComponent`; logic pembuatan, penghapusan, transform,
/// dan load model ada di system ini. System tidak menyimpan state entity.
final class SceneObjectSystem: System {
    private static let query = EntityQuery(where: .has(SceneObjectComponent.self))

    required init(scene: Scene) {
    }

    func update(context: SceneUpdateContext) {
        for _ in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            // Tetap ringan: transform object diterapkan saat sync scene atau gesture.
            // Jangan assign transform tiap frame karena itu membuat CPU naik tanpa
            // perubahan visual yang nyata.
        }
    }

    @MainActor
    static func synchronize(
        anchor: Entity,
        requestedObjects: [ObjectConfiguration],
        selectedTexture: MaterialTexture,
        lastTexture: inout MaterialTexture?,
        reportImportedDimensions: @escaping (UUID, SIMD3<Float>) -> Void,
        reportModelLoadFailure: @escaping (String, any Error) -> Void,
        debugLog: @escaping (String) -> Void
    ) {
        let currentIDs = Set(requestedObjects.map { $0.id })

        for entity in entitiesWithObjectComponent(in: anchor) {
            guard let component = entity.components[SceneObjectComponent.self],
                  !currentIDs.contains(component.configuration.id) else { continue }
                        CollisionSystem.removeObstacle(from: entity)
            entity.removeFromParent()
            debugLog("Object deletion cleaned up from scene")
        }

        let textureChanged = lastTexture != selectedTexture
        for configuration in requestedObjects {
            let sourceKey = objectSourceKey(for: configuration)
            let existingEntity = entityWithObjectID(configuration.id, in: anchor)
            let existingComponent = existingEntity?.components[SceneObjectComponent.self]
            let needsReplacement = existingEntity == nil || existingComponent?.sourceKey != sourceKey || (configuration.importedModel == nil && textureChanged)

            let objectEntity: Entity
            if needsReplacement {
                existingEntity?.removeFromParent()

                if let importedModel = configuration.importedModel {
                    let placeholder = SceneObjectSystem.makeObject(type: .cuboid)
                    placeholder.name = configuration.id.uuidString
                    placeholder.components.set(SceneObjectComponent(configuration: configuration, sourceKey: sourceKey))
                    anchor.addChild(placeholder)
                    objectEntity = placeholder

                    loadImportedObject(
                        importedModel,
                        objectID: configuration.id,
                        currentPlaceholder: placeholder,
                        sourceKey: sourceKey,
                        anchor: anchor,
                        reportImportedDimensions: reportImportedDimensions,
                        reportModelLoadFailure: reportModelLoadFailure,
                        debugLog: debugLog
                    )
                } else {
                    let realityKitEntity = SceneObjectSystem.makeObject(
                        type: configuration.type,
                        texture: selectedTexture
                    )
                    realityKitEntity.name = configuration.id.uuidString
                    realityKitEntity.components.set(SceneObjectComponent(configuration: configuration, sourceKey: sourceKey))
                    anchor.addChild(realityKitEntity)
                    objectEntity = realityKitEntity
                    debugLog("Object synchronized: \(configuration.name) - \(configuration.type.rawValue)")
                }
            } else if let existingEntity {
                objectEntity = existingEntity
            } else {
                continue
            }

            var component = objectEntity.components[SceneObjectComponent.self] ?? SceneObjectComponent(
                configuration: configuration,
                sourceKey: sourceKey
            )
            component.configuration = configuration
            component.sourceKey = sourceKey
            objectEntity.components.set(component)
            applyTransform(to: objectEntity, configuration: configuration)
            CollisionSystem.setObstacle(
                on: objectEntity,
                id: configuration.id,
                radius: SceneObjectSystem.collisionRadius(for: configuration)
            )
        }

        lastTexture = selectedTexture
    }

    static func selectObject(containing entity: Entity) -> UUID? {
        var candidate: Entity? = entity
        while let current = candidate {
            if let component = current.components[SceneObjectComponent.self] {
                return component.configuration.id
            }
            candidate = current.parent
        }
        return nil
    }

    static func entityWithObjectID(_ id: UUID, in root: Entity) -> Entity? {
        entitiesWithObjectComponent(in: root).first {
            $0.components[SceneObjectComponent.self]?.configuration.id == id
        }
    }

    @MainActor
    private static func loadImportedObject(
        _ importedModel: ImportedModelConfiguration,
        objectID: UUID,
        currentPlaceholder: Entity,
        sourceKey: String,
        anchor: Entity,
        reportImportedDimensions: @escaping (UUID, SIMD3<Float>) -> Void,
        reportModelLoadFailure: @escaping (String, any Error) -> Void,
        debugLog: @escaping (String) -> Void
    ) {
        Task { @MainActor in
            do {
                let loadedEntity = try await Entity(contentsOf: importedModel.fileURL)
                try Task.checkCancellation()

                guard let currentComponent = currentPlaceholder.components[SceneObjectComponent.self],
                      currentComponent.sourceKey == sourceKey,
                      currentComponent.configuration.importedModel?.fileURL == importedModel.fileURL else { return }

                let normalizedObject = try makeNormalizedImportedObject(
                    from: loadedEntity,
                    id: currentComponent.configuration.id
                )
                normalizedObject.entity.components.set(SceneObjectComponent(
                    configuration: currentComponent.configuration,
                    sourceKey: sourceKey
                ))
                applyTransform(to: normalizedObject.entity, configuration: currentComponent.configuration)
                CollisionSystem.setObstacle(
                    on: normalizedObject.entity,
                    id: objectID,
                    radius: SceneObjectSystem.collisionRadius(for: currentComponent.configuration)
                )

                currentPlaceholder.removeFromParent()
                anchor.addChild(normalizedObject.entity)
                reportImportedDimensions(objectID, normalizedObject.dimensions)
                debugLog("Imported 3D model loaded: \(importedModel.displayName)")
            } catch is CancellationError {
                /* stale load ignored by component identity */
            } catch {
                /* stale load ignored by component identity */
                reportModelLoadFailure(importedModel.displayName, error)
            }
        }
    }

    private static func makeNormalizedImportedObject(
        from loadedEntity: Entity,
        id: UUID
    ) throws -> (entity: Entity, dimensions: SIMD3<Float>) {
        let normalizer = Entity()
        normalizer.addChild(loadedEntity)
        let bounds = normalizer.visualBounds(recursive: true, relativeTo: normalizer)
        let rawDimensions = bounds.extents
        let largestDimension = max(rawDimensions.x, rawDimensions.y, rawDimensions.z)

        guard largestDimension.isFinite, largestDimension > 0.0001 else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let normalizationScale = ImportedModelConfiguration.targetMaximumDimension / largestDimension
        let dimensions = SIMD3<Float>(
            max(rawDimensions.x * normalizationScale, 0.002),
            max(rawDimensions.y * normalizationScale, 0.002),
            max(rawDimensions.z * normalizationScale, 0.002)
        )
        normalizer.scale = SIMD3<Float>(repeating: normalizationScale)
        normalizer.position = -bounds.center * normalizationScale

        let container = Entity()
        container.name = id.uuidString
        container.addChild(normalizer)
        container.components.set(CollisionComponent(shapes: [.generateBox(size: dimensions)]))
        enableDynamicShadows(on: loadedEntity)
        return (container, dimensions)
    }

    private static func enableDynamicShadows(on entity: Entity) {
        if entity is ModelEntity {
            entity.components.set(DynamicLightShadowComponent(castsShadow: true))
        }
        for child in entity.children {
            enableDynamicShadows(on: child)
        }
    }

    private static func objectSourceKey(for object: ObjectConfiguration) -> String {
        if let importedModel = object.importedModel {
            return "imported:\(importedModel.fileURL.path)"
        }
        return "primitive:\(object.type.rawValue)"
    }

    static func applyTransform(to object: Entity, configuration: ObjectConfiguration) {
        let scaledHeight = SceneObjectSystem.objectHeight(for: configuration) * configuration.scale
        object.position = SIMD3<Float>(
            configuration.position.x,
            scaledHeight / 2,
            configuration.position.z
        )
        object.scale = SIMD3<Float>(repeating: configuration.scale)
        object.orientation = simd_quatf(
            angle: configuration.yawDegrees.degreesToRadians,
            axis: SIMD3<Float>(0, 1, 0)
        )
    }

    static func objectHeight(for object: ObjectConfiguration) -> Float {
        baseDimensions(for: object).y
    }

    static func baseDimensions(for type: LearningObjectType) -> SIMD3<Float> {
        switch type {
        case .cube:
            SIMD3<Float>(repeating: cubeSize)
        case .sphere:
            SIMD3<Float>(repeating: sphereRadius * 2)
        case .cuboid:
            cuboidSize
        case .cylinder:
            SIMD3<Float>(cylinderRadius * 2, cylinderHeight, cylinderRadius * 2)
        case .cone:
            SIMD3<Float>(coneRadius * 2, coneHeight, coneRadius * 2)
        case .hemisphere:
            SIMD3<Float>(hemisphereRadius * 2, hemisphereRadius, hemisphereRadius * 2)
        case .squarePyramid:
            SIMD3<Float>(squarePyramidSize, squarePyramidHeight, squarePyramidSize)
        case .triangularPyramid:
            SIMD3<Float>(triangularPyramidSize, triangularPyramidHeight, triangularPyramidSize)
        }
    }

    static func baseDimensions(for object: ObjectConfiguration) -> SIMD3<Float> {
        object.importedModel?.dimensions ?? baseDimensions(for: object.type)
    }

    static func collisionRadius(for object: ObjectConfiguration) -> Float {
        simd_length(baseDimensions(for: object) * object.scale) / 2
    }

    static func obstaclePosition(for object: ObjectConfiguration) -> SIMD3<Float> {
        object.position + SIMD3<Float>(0, SceneObjectSystem.objectHeight(for: object) * object.scale / 2, 0)
    }

    private static func entitiesWithObjectComponent(in root: Entity) -> [Entity] {
        var result: [Entity] = []
        collectObjectEntities(from: root, into: &result)
        return result
    }

    private static func collectObjectEntities(from entity: Entity, into result: inout [Entity]) {
        if entity.components[SceneObjectComponent.self] != nil {
            result.append(entity)
        }
        for child in entity.children {
            collectObjectEntities(from: child, into: &result)
        }
    }
}


extension SceneObjectSystem {
    static let cubeSize: Float = 0.12
    static let sphereRadius: Float = 0.06
    static let cuboidSize = SIMD3<Float>(0.17, 0.10, 0.11)
    static let cylinderHeight: Float = 0.14
    static let cylinderRadius: Float = 0.05
    static let coneHeight: Float = 0.14
    static let coneRadius: Float = 0.06
    static let hemisphereRadius: Float = 0.07
    static let squarePyramidSize: Float = 0.13
    static let squarePyramidHeight: Float = 0.15
    static let triangularPyramidSize: Float = 0.15
    static let triangularPyramidHeight: Float = 0.15

    static func makeObject(type: LearningObjectType, texture: MaterialTexture = .defaultGrid) -> ModelEntity {
        let mesh: MeshResource
        let height: Float

        switch type {
        case .cube:
            mesh = .generateBox(size: cubeSize)
            height = cubeSize
        case .sphere:
            mesh = .generateSphere(radius: sphereRadius)
            height = sphereRadius * 2
        case .cuboid:
            mesh = .generateBox(size: cuboidSize)
            height = cuboidSize.y
        case .cylinder:
            mesh = .generateCylinder(height: cylinderHeight, radius: cylinderRadius)
            height = cylinderHeight
        case .cone:
            mesh = .generateCone(height: coneHeight, radius: coneRadius)
            height = coneHeight
        case .hemisphere:
            mesh = makeHemisphere(radius: hemisphereRadius)
            height = hemisphereRadius
        case .squarePyramid:
            mesh = makeSquarePyramid(baseSize: squarePyramidSize, height: squarePyramidHeight)
            height = squarePyramidHeight
        case .triangularPyramid:
            mesh = makeTriangularPyramid(baseSize: triangularPyramidSize, height: triangularPyramidHeight)
            height = triangularPyramidHeight
        }

        let material = makeMaterial(for: texture)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = type.rawValue
        entity.position.y = height / 2
        entity.generateCollisionShapes(recursive: false)
        entity.components.set(DynamicLightShadowComponent(castsShadow: true))
        return entity
    }


    private static func makeSquarePyramid(baseSize: Float, height: Float) -> MeshResource {
        let halfBase = baseSize / 2
        let halfHeight = height / 2
        let vertices = [
            SIMD3<Float>(-halfBase, -halfHeight, -halfBase),
            SIMD3<Float>(halfBase, -halfHeight, -halfBase),
            SIMD3<Float>(halfBase, -halfHeight, halfBase),
            SIMD3<Float>(-halfBase, -halfHeight, halfBase),
            SIMD3<Float>(0, halfHeight, 0)
        ]
        return makeTriangleMesh(
            name: "Square Pyramid",
            triangles: [
                (vertices[0], vertices[1], vertices[2]),
                (vertices[0], vertices[2], vertices[3]),
                (vertices[0], vertices[4], vertices[1]),
                (vertices[1], vertices[4], vertices[2]),
                (vertices[2], vertices[4], vertices[3]),
                (vertices[3], vertices[4], vertices[0])
            ],
            center: .zero
        )
    }

    private static func makeTriangularPyramid(baseSize: Float, height: Float) -> MeshResource {
        let halfHeight = height / 2
        let baseRadius = baseSize / sqrt(3)
        let vertices = [
            SIMD3<Float>(0, -halfHeight, -baseRadius),
            SIMD3<Float>(-baseSize / 2, -halfHeight, baseRadius / 2),
            SIMD3<Float>(baseSize / 2, -halfHeight, baseRadius / 2),
            SIMD3<Float>(0, halfHeight, 0)
        ]
        return makeTriangleMesh(
            name: "Triangular Pyramid",
            triangles: [
                (vertices[0], vertices[2], vertices[1]),
                (vertices[0], vertices[3], vertices[2]),
                (vertices[2], vertices[3], vertices[1]),
                (vertices[1], vertices[3], vertices[0])
            ],
            center: .zero
        )
    }

    private static func makeHemisphere(radius: Float) -> MeshResource {
        let verticalSegments = 8
        let radialSegments = 24
        let sphereCenter = SIMD3<Float>(0, -radius / 2, 0)
        var triangles: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] = []

        for verticalIndex in 0..<verticalSegments {
            let phi0 = Float(verticalIndex) / Float(verticalSegments) * (.pi / 2)
            let phi1 = Float(verticalIndex + 1) / Float(verticalSegments) * (.pi / 2)

            for radialIndex in 0..<radialSegments {
                let theta0 = Float(radialIndex) / Float(radialSegments) * (.pi * 2)
                let theta1 = Float(radialIndex + 1) / Float(radialSegments) * (.pi * 2)
                let upperLeft = hemispherePoint(radius: radius, phi: phi0, theta: theta0)
                let upperRight = hemispherePoint(radius: radius, phi: phi0, theta: theta1)
                let lowerLeft = hemispherePoint(radius: radius, phi: phi1, theta: theta0)
                let lowerRight = hemispherePoint(radius: radius, phi: phi1, theta: theta1)

                triangles.append((upperLeft, lowerLeft, lowerRight))
                if verticalIndex != 0 {
                    triangles.append((upperLeft, lowerRight, upperRight))
                }
            }
        }

        let baseCenter = SIMD3<Float>(0, -radius / 2, 0)
        for radialIndex in 0..<radialSegments {
            let theta0 = Float(radialIndex) / Float(radialSegments) * (.pi * 2)
            let theta1 = Float(radialIndex + 1) / Float(radialSegments) * (.pi * 2)
            triangles.append((
                baseCenter,
                hemispherePoint(radius: radius, phi: .pi / 2, theta: theta0),
                hemispherePoint(radius: radius, phi: .pi / 2, theta: theta1)
            ))
        }

        return makeTriangleMesh(name: "Hemisphere", triangles: triangles, center: sphereCenter)
    }

    private static func hemispherePoint(radius: Float, phi: Float, theta: Float) -> SIMD3<Float> {
        let ringRadius = sin(phi) * radius
        return SIMD3<Float>(
            cos(theta) * ringRadius,
            cos(phi) * radius - radius / 2,
            sin(theta) * ringRadius
        )
    }

    private static func makeTriangleMesh(
        name: String,
        triangles: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)],
        center: SIMD3<Float>
    ) -> MeshResource {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var textureCoordinates: [SIMD2<Float>] = []
        var indices: [UInt32] = []

        for triangle in triangles {
            let first = triangle.0
            var second = triangle.1
            var third = triangle.2
            var normal = simd_normalize(simd_cross(second - first, third - first))
            let faceCenter = (first + second + third) / 3

            if simd_dot(normal, faceCenter - center) < 0 {
                swap(&second, &third)
                normal = -normal
            }

            let startIndex = UInt32(positions.count)
            positions.append(contentsOf: [first, second, third])
            normals.append(contentsOf: [normal, normal, normal])
            textureCoordinates.append(contentsOf: [
                textureCoordinate(for: first),
                textureCoordinate(for: second),
                textureCoordinate(for: third)
            ])
            indices.append(contentsOf: [startIndex, startIndex + 1, startIndex + 2])
        }

        var descriptor = MeshDescriptor(name: name)
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(textureCoordinates)
        descriptor.primitives = .triangles(indices)

        return (try? MeshResource.generate(from: [descriptor])) ?? .generateBox(size: 0.1)
    }

    private static func textureCoordinate(for position: SIMD3<Float>) -> SIMD2<Float> {
        let wrappedU = position.x * 8
        let wrappedV = position.z * 8
        return SIMD2<Float>(
            wrappedU - floor(wrappedU),
            wrappedV - floor(wrappedV)
        )
    }

    static func makeMaterial(for texture: MaterialTexture) -> PhysicallyBasedMaterial {
        let image = UIImage(named: texture.assetName) ?? proceduralImage(for: texture)
        var material = PhysicallyBasedMaterial()

        if let cgImage = image.cgImage,
           let resource = try? TextureResource(
                image: cgImage,
                withName: texture.assetName,
                options: .init(semantic: .color)
           ) {
            material.baseColor = .init(texture: .init(resource))
        } else {
            material.baseColor = .init(tint: UIColor(red: texture.fallbackColor.red, green: texture.fallbackColor.green, blue: texture.fallbackColor.blue, alpha: texture.fallbackColor.alpha))
        }

        material.roughness = .init(floatLiteral: texture.roughness)
        material.metallic = .init(floatLiteral: texture.isMetallic ? 1 : 0)

        if texture.shadowBehavior == .cutout {
            material.opacityThreshold = 0.55
            material.blending = .transparent(opacity: .init(floatLiteral: 0.72))
        } else {
            material.blending = .opaque
        }

        return material
    }

    static func proceduralImage(for texture: MaterialTexture, size: Int = 256) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            UIColor(red: texture.fallbackColor.red, green: texture.fallbackColor.green, blue: texture.fallbackColor.blue, alpha: texture.fallbackColor.alpha).setFill()
            context.fill(rect)

            switch texture.id {
            case "grid":
                UIColor(white: 0.95, alpha: 1).setFill()
                for index in stride(from: 0, through: size, by: 32) {
                    context.fill(CGRect(x: index, y: 0, width: 3, height: size))
                    context.fill(CGRect(x: 0, y: index, width: size, height: 3))
                }
            case "marble":
                for index in 0..<14 {
                    let y = CGFloat(index * 21)
                    let path = UIBezierPath()
                    path.move(to: CGPoint(x: -20, y: y))
                    path.addCurve(
                        to: CGPoint(x: CGFloat(size) + 20, y: y + CGFloat((index % 3) * 18 - 12)),
                        controlPoint1: CGPoint(x: 70, y: y - 28),
                        controlPoint2: CGPoint(x: 170, y: y + 34)
                    )
                    UIColor(white: index % 2 == 0 ? 0.68 : 0.98, alpha: 0.55).setStroke()
                    path.lineWidth = CGFloat(index % 2 == 0 ? 3 : 1)
                    path.stroke()
                }
            case "wood":
                for index in 0..<18 {
                    let y = CGFloat(index * 15)
                    let path = UIBezierPath()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addCurve(
                        to: CGPoint(x: CGFloat(size), y: y + CGFloat((index % 4) * 6 - 9)),
                        controlPoint1: CGPoint(x: 64, y: y + 14),
                        controlPoint2: CGPoint(x: 190, y: y - 18)
                    )
                    UIColor(red: 0.35, green: 0.20, blue: 0.09, alpha: 0.42).setStroke()
                    path.lineWidth = 4
                    path.stroke()
                }
            case "metal":
                for index in stride(from: 0, to: size, by: 24) {
                    let alpha = CGFloat(index % 48 == 0 ? 0.18 : 0.08)
                    UIColor(white: 1, alpha: alpha).setFill()
                    context.fill(CGRect(x: 0, y: index, width: size, height: 1))
                }
                UIColor(white: 0.35, alpha: 0.10).setFill()
                context.fill(rect)
            case "cutout":
                context.cgContext.setBlendMode(.clear)
                for y in stride(from: 18, to: size, by: 48) {
                    for x in stride(from: 18, to: size, by: 48) {
                        context.cgContext.fillEllipse(in: CGRect(x: x, y: y, width: 20, height: 20))
                    }
                }
                context.cgContext.setBlendMode(.normal)
                UIColor(red: 0.52, green: 0.42, blue: 0.18, alpha: 0.35).setStroke()
                context.cgContext.setLineWidth(2)
                for y in stride(from: 18, to: size, by: 48) {
                    for x in stride(from: 18, to: size, by: 48) {
                        context.cgContext.strokeEllipse(in: CGRect(x: x, y: y, width: 20, height: 20))
                    }
                }
            default:
                break
            }
        }
    }
}
