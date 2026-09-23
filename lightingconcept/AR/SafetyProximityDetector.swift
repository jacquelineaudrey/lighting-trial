import ARKit
import Foundation
import simd

/// Finds classified real-world surfaces that are closer than the safety margin.
/// ARKit supplies both the classification and the 3D mesh position, which makes
/// it a better real-time safety signal than a language model guessing distance
/// from a camera image.
nonisolated final class SafetyProximityDetector: @unchecked Sendable {
    static let warningDistanceMeters: Float = 0.5

    private let lock = NSLock()
    private var meshAnchors: [UUID: ARMeshAnchor] = [:]
    private var planeAnchors: [UUID: ARPlaneAnchor] = [:]
    private var lastEvaluationTimestamp = -Double.greatestFiniteMagnitude
    private var lastWarning: SafetyProximityWarning?
    private var hazardIsActive = false
    private var clearSince: TimeInterval?

    private let evaluationInterval: TimeInterval = 0.12
    private let clearHysteresisMeters: Float = 0.12
    private let clearHysteresisDuration: TimeInterval = 0.7
    private let maximumFacesPerAnchor = 1_200

    func update(from anchors: [ARAnchor]) {
        lock.lock()
        defer { lock.unlock() }

        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                meshAnchors[meshAnchor.identifier] = meshAnchor
            } else if let planeAnchor = anchor as? ARPlaneAnchor {
                planeAnchors[planeAnchor.identifier] = planeAnchor
            }
        }
    }

    func remove(anchors: [ARAnchor]) {
        lock.lock()
        defer { lock.unlock() }

        for anchor in anchors {
            meshAnchors[anchor.identifier] = nil
            planeAnchors[anchor.identifier] = nil
        }
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }

        meshAnchors.removeAll()
        planeAnchors.removeAll()
        lastEvaluationTimestamp = -Double.greatestFiniteMagnitude
        lastWarning = nil
        hazardIsActive = false
        clearSince = nil
    }

    func warning(cameraPosition: SIMD3<Float>, timestamp: TimeInterval) -> SafetyProximityWarning? {
        lock.lock()
        defer { lock.unlock() }

        guard timestamp - lastEvaluationTimestamp >= evaluationInterval else {
            return lastWarning
        }
        lastEvaluationTimestamp = timestamp

        let nearestWarning = nearestWarning(to: cameraPosition)
        if let nearestWarning,
           nearestWarning.distanceMeters < Self.warningDistanceMeters {
            hazardIsActive = true
            clearSince = nil
            lastWarning = nearestWarning
            return nearestWarning
        }

        guard hazardIsActive else {
            lastWarning = nil
            return nil
        }

        if clearSince == nil {
            clearSince = timestamp
        }

        let clearDistance = Self.warningDistanceMeters + clearHysteresisMeters
        let isFarEnough: Bool
        if let nearestWarning {
            isFarEnough = nearestWarning.distanceMeters >= clearDistance
        } else {
            isFarEnough = true
        }
        let hasBeenClearLongEnough = timestamp - (clearSince ?? timestamp) >= clearHysteresisDuration

        guard isFarEnough, hasBeenClearLongEnough else {
            return lastWarning
        }

        hazardIsActive = false
        clearSince = nil
        lastWarning = nil
        return nil
    }

    private func nearestWarning(to cameraPosition: SIMD3<Float>) -> SafetyProximityWarning? {
        let meshWarning = meshAnchors.values
            .compactMap { nearestWarning(in: $0, to: cameraPosition) }
            .min { $0.distanceMeters < $1.distanceMeters }

        let planeWarning = planeAnchors.values
            .compactMap { nearestWarning(in: $0, to: cameraPosition) }
            .min { $0.distanceMeters < $1.distanceMeters }

        return [meshWarning, planeWarning]
            .compactMap { $0 }
            .min { $0.distanceMeters < $1.distanceMeters }
    }

    private func nearestWarning(
        in anchor: ARMeshAnchor,
        to cameraPosition: SIMD3<Float>
    ) -> SafetyProximityWarning? {
        let geometry = anchor.geometry
        guard let classifications = geometry.classification,
              geometry.faces.count > 0,
              classifications.count > 0 else {
            return nil
        }

        let faceCount = min(geometry.faces.count, classifications.count)
        let sampleStride = max(faceCount / maximumFacesPerAnchor, 1)
        var nearest: SafetyProximityWarning?

        for faceIndex in stride(from: 0, to: faceCount, by: sampleStride) {
            guard let classification = classification(at: faceIndex, in: classifications),
                  let objectName = objectName(for: classification) else {
                continue
            }

            let faces = geometry.faces
            for vertexOffset in 0..<faces.indexCountPerPrimitive {
                let vertexIndex = index(
                    atFace: faceIndex,
                    vertexOffset: vertexOffset,
                    in: faces
                )
                let localVertex = vertex(at: Int(vertexIndex), in: geometry.vertices)
                let worldVertex = anchor.transform * SIMD4<Float>(
                    localVertex.x,
                    localVertex.y,
                    localVertex.z,
                    1
                )
                let distance = simd_distance(
                    cameraPosition,
                    SIMD3<Float>(worldVertex.x, worldVertex.y, worldVertex.z)
                )

                guard distance < Self.warningDistanceMeters else { continue }

                let candidate = SafetyProximityWarning(
                    objectName: objectName,
                    distanceMeters: distance
                )
                if let currentNearest = nearest,
                   distance >= currentNearest.distanceMeters {
                    continue
                }
                nearest = candidate
            }
        }

        return nearest
    }

    private func nearestWarning(
        in anchor: ARPlaneAnchor,
        to cameraPosition: SIMD3<Float>
    ) -> SafetyProximityWarning? {
        guard let objectName = objectName(for: anchor.classification) else { return nil }

        let halfWidth = anchor.planeExtent.width * 0.5
        let halfHeight = anchor.planeExtent.height * 0.5
        let sampleFractions: [Float] = [-1, -0.5, 0, 0.5, 1]
        var nearestDistance = Float.greatestFiniteMagnitude

        for xFraction in sampleFractions {
            for zFraction in sampleFractions {
                let localPoint = SIMD4<Float>(
                    anchor.center.x + halfWidth * xFraction,
                    0,
                    anchor.center.z + halfHeight * zFraction,
                    1
                )
                let worldPoint = anchor.transform * localPoint
                let distance = simd_distance(
                    cameraPosition,
                    SIMD3<Float>(worldPoint.x, worldPoint.y, worldPoint.z)
                )
                nearestDistance = min(nearestDistance, distance)
            }
        }

        guard nearestDistance < Self.warningDistanceMeters else { return nil }
        return SafetyProximityWarning(
            objectName: objectName,
            distanceMeters: nearestDistance
        )
    }

    private func objectName(for classification: ARMeshClassification) -> String? {
        switch classification {
        case .table:
            "meja"
        case .seat:
            "kursi"
        case .wall:
            "dinding"
        case .door:
            "pintu"
        case .window:
            "jendela"
        case .ceiling:
            "langit-langit"
        default:
            nil
        }
    }

    private func objectName(for classification: ARPlaneAnchor.Classification) -> String? {
        switch classification {
        case .table:
            "meja"
        case .seat:
            "kursi"
        case .wall:
            "dinding"
        case .door:
            "pintu"
        case .window:
            "jendela"
        case .ceiling:
            "langit-langit"
        default:
            nil
        }
    }

    private func classification(at index: Int, in source: ARGeometrySource) -> ARMeshClassification? {
        let pointer = source.buffer.contents()
            .advanced(by: source.offset + source.stride * index)
            .assumingMemoryBound(to: UInt8.self)
        return ARMeshClassification(rawValue: Int(pointer.pointee))
    }

    private func vertex(at index: Int, in source: ARGeometrySource) -> SIMD3<Float> {
        let pointer = source.buffer.contents()
            .advanced(by: source.offset + source.stride * index)
            .assumingMemoryBound(to: SIMD3<Float>.self)
        return pointer.pointee
    }

    private func index(
        atFace faceIndex: Int,
        vertexOffset: Int,
        in faces: ARGeometryElement
    ) -> UInt32 {
        let offset = (faceIndex * faces.indexCountPerPrimitive + vertexOffset) * faces.bytesPerIndex
        let pointer = faces.buffer.contents().advanced(by: offset)

        if faces.bytesPerIndex == MemoryLayout<UInt16>.size {
            return UInt32(pointer.assumingMemoryBound(to: UInt16.self).pointee)
        }

        return pointer.assumingMemoryBound(to: UInt32.self).pointee
    }
}
