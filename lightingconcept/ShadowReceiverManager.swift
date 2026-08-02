import ARKit
import RealityKit

final class ShadowReceiverManager {
    private var shadowReceiver: ModelEntity?

    func setupReceiver(on anchor: AnchorEntity, usesFlatFallback: Bool, surfaceTexture: MaterialTexture) {
        guard shadowReceiver == nil else {
            return
        }

        // Receiver memakai OcclusionMaterial agar kamera tetap terlihat, tetapi dynamic
        // shadow dari virtual object masih bisa jatuh ke permukaan virtual ini.
        var receiverMaterial = OcclusionMaterial(receivesDynamicLighting: true)
        receiverMaterial.faceCulling = .none

        // Box sangat tipis lebih stabil daripada plane 2D untuk shadow dari berbagai
        // sudut kamera. Secara visual tetap berperan sebagai permukaan datar.
        let receiver = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(8.0, 0.004, 8.0)),
            materials: [receiverMaterial]
        )
        receiver.name = usesFlatFallback ? "Stable volumetric shadow receiver fallback" : "Stable AR shadow receiver"
        receiver.position.y = -0.004
        receiver.components.set(DynamicLightShadowComponent(castsShadow: false))
        receiver.components.set(GroundingShadowComponent(castsShadow: false, receivesShadow: true))
        anchor.addChild(receiver)
        shadowReceiver = receiver

        print("[ARShadowLearning] Shadow receiver setup: stable volumetric occlusion shadow catcher")
    }

    func updateSurfaceTexture(_ texture: MaterialTexture) {
        // The receiver intentionally stays invisible. A visible transparent
        // surface plane makes the camera feed look hazy in AR.
    }

    func reset() {
        shadowReceiver?.removeFromParent()
        shadowReceiver = nil
    }
}

final class LiDARMeshOcclusionManager {
    private var meshAnchors: [UUID: AnchorEntity] = [:]
    private var visualMeshes: [UUID: ModelEntity] = [:]
    private var faceCounts: [UUID: Int] = [:]
    private var lastUpdateTimes: [UUID: TimeInterval] = [:]
    private let minimumUpdateInterval: TimeInterval = 0.45
    private var visualizationEnabled = true

    func setVisualizationEnabled(_ enabled: Bool) {
        visualizationEnabled = enabled
        visualMeshes.values.forEach { $0.isEnabled = enabled }
    }

    func update(from anchors: [ARAnchor], in arView: ARView) -> (updatedCount: Int, meshCount: Int, faceCount: Int) {
        var updatedCount = 0
        let now = ProcessInfo.processInfo.systemUptime

        // ARMeshAnchor berasal dari LiDAR scene reconstruction. Di app ini mesh dibuat
        // visible saat scanning sebagai feedback area yang sudah terbaca oleh device.
        for meshAnchor in anchors.compactMap({ $0 as? ARMeshAnchor }) {
            if let lastUpdate = lastUpdateTimes[meshAnchor.identifier],
               now - lastUpdate < minimumUpdateInterval {
                continue
            }

            guard let mesh = makeMeshResource(from: meshAnchor.geometry) else {
                continue
            }

            meshAnchors[meshAnchor.identifier]?.removeFromParent()

            let anchorEntity = AnchorEntity(world: meshAnchor.transform)
            anchorEntity.name = "LiDAR scan visualization mesh"
            let visualEntity = makeScanVisualizationEntity(mesh: mesh)
            visualEntity.isEnabled = visualizationEnabled
            anchorEntity.addChild(visualEntity)

            arView.scene.addAnchor(anchorEntity)

            meshAnchors[meshAnchor.identifier] = anchorEntity
            visualMeshes[meshAnchor.identifier] = visualEntity
            faceCounts[meshAnchor.identifier] = meshAnchor.geometry.faces.count
            lastUpdateTimes[meshAnchor.identifier] = now
            updatedCount += 1
        }

        return (updatedCount, meshAnchors.count, totalFaceCount)
    }

    func remove(anchors: [ARAnchor]) {
        for anchor in anchors {
            meshAnchors[anchor.identifier]?.removeFromParent()
            meshAnchors[anchor.identifier] = nil
            visualMeshes[anchor.identifier] = nil
            faceCounts[anchor.identifier] = nil
            lastUpdateTimes[anchor.identifier] = nil
        }
    }

    func reset() {
        meshAnchors.values.forEach { $0.removeFromParent() }
        meshAnchors.removeAll()
        visualMeshes.removeAll()
        faceCounts.removeAll()
        lastUpdateTimes.removeAll()
        visualizationEnabled = true
    }

    private var totalFaceCount: Int {
        faceCounts.values.reduce(0, +)
    }

    private func makeMeshResource(from geometry: ARMeshGeometry) -> MeshResource? {
        // ARMeshGeometry menyimpan vertex/index dalam Metal buffer. Data ini dikonversi
        // ke MeshDescriptor supaya bisa divisualisasikan oleh RealityKit.
        let vertexCount = geometry.vertices.count
        let faceCount = geometry.faces.count
        guard vertexCount > 0, faceCount > 0 else { return nil }

        var positions: [SIMD3<Float>] = []
        positions.reserveCapacity(vertexCount)
        for index in 0..<vertexCount {
            positions.append(vertex(at: index, in: geometry.vertices))
        }

        var indices: [UInt32] = []
        indices.reserveCapacity(faceCount * geometry.faces.indexCountPerPrimitive)
        for faceIndex in 0..<faceCount {
            for vertexIndex in 0..<geometry.faces.indexCountPerPrimitive {
                indices.append(index(atFace: faceIndex, vertexOffset: vertexIndex, in: geometry.faces))
            }
        }

        var descriptor = MeshDescriptor(name: "LiDAR occlusion")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.primitives = .triangles(indices)

        return try? MeshResource.generate(from: [descriptor])
    }

    private func makeScanVisualizationEntity(mesh: MeshResource) -> ModelEntity {
        let material = SimpleMaterial(
            color: UIColor.systemCyan.withAlphaComponent(0.18),
            roughness: .init(floatLiteral: 1),
            isMetallic: false
        )
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = "LiDAR scanned area preview"
        entity.components.set(DynamicLightShadowComponent(castsShadow: false))
        return entity
    }

    private func vertex(at index: Int, in source: ARGeometrySource) -> SIMD3<Float> {
        let pointer = source.buffer.contents()
            .advanced(by: source.offset + source.stride * index)
            .assumingMemoryBound(to: SIMD3<Float>.self)
        return pointer.pointee
    }

    private func index(atFace faceIndex: Int, vertexOffset: Int, in faces: ARGeometryElement) -> UInt32 {
        let offset = (faceIndex * faces.indexCountPerPrimitive + vertexOffset) * faces.bytesPerIndex
        let pointer = faces.buffer.contents().advanced(by: offset)

        if faces.bytesPerIndex == MemoryLayout<UInt16>.size {
            return UInt32(pointer.assumingMemoryBound(to: UInt16.self).pointee)
        }

        return pointer.assumingMemoryBound(to: UInt32.self).pointee
    }
}
