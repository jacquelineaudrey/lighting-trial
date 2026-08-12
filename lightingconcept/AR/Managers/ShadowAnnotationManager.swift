import RealityKit
import Combine
import UIKit

final class ShadowAnnotationManager {
    private let root = Entity()
    private var dots: [ModelEntity] = []
    private var pulseRings: [PulseRing] = []
    private var updateSubscription: Cancellable?
    private static var cachedRingTexture: TextureResource?

    private let dotRadius: Float = 0.004
    private let tapTargetRadius: Float = 0.01
    private let ringDiameter: Float = 0.01
    private let pulseStartScale: Float = 1.0
    private let pulseEndScale: Float = 2.6
    private let pulseDuration: TimeInterval = 1.3
    private let markerColor: UIColor = .white

    private struct PulseRing {
        let entity: ModelEntity
        let startTime: Date
    }

    func attach(to anchor: AnchorEntity) {
        if root.parent == nil {
            anchor.addChild(root)
        }
        subscribeToUpdatesIfNeeded()
    }

    func clear() {
        dots.forEach { $0.removeFromParent() }
        dots.removeAll()
        pulseRings.forEach { $0.entity.removeFromParent() }
        pulseRings.removeAll()
    }

    func update(
        visible: Bool,
        objectType: LearningObjectType,
        objectPosition: SIMD3<Float>,
        objectHeight: Float,
        selectedLight: LightConfiguration
    ) {
        clear()
        guard visible else { return }

        subscribeToUpdatesIfNeeded()

        let concepts: [(ShadowConcept, SIMD3<Float>)]
        if objectType == .cube {
            concepts = [
                (.lightSide, objectPosition + SIMD3<Float>(-0.08, objectHeight * 0.72, 0)),
                (.shadowSide, objectPosition + SIMD3<Float>(0.08, objectHeight * 0.5, 0)),
                (.castShadow, objectPosition + shadowOffset(light: selectedLight, object: objectPosition, scale: 0.24)),
                (.contactShadow, objectPosition + SIMD3<Float>(0, 0.025, 0.08))
            ]
        } else {
            concepts = [
                (.highlight, objectPosition + SIMD3<Float>(-0.05, objectHeight * 0.86, 0)),
                (.lightSide, objectPosition + SIMD3<Float>(-0.08, objectHeight * 0.62, 0)),
                (.terminator, objectPosition + SIMD3<Float>(0, objectHeight * 0.72, 0.07)),
                (.coreShadow, objectPosition + SIMD3<Float>(0, objectHeight * 0.5, 0)),
                (.reflectedLight, objectPosition + SIMD3<Float>(0.04, objectHeight * 0.34, 0.06)),
                (.castShadow, objectPosition + shadowOffset(light: selectedLight, object: objectPosition, scale: 0.24)),
                (.contactShadow, objectPosition + SIMD3<Float>(0, 0.025, 0.08))
            ]
        }

        for (concept, position) in concepts {
            addMarker(concept: concept, position: position)
        }
    }

    private func subscribeToUpdatesIfNeeded() {
        guard updateSubscription == nil, let scene = root.scene else { return }
        updateSubscription = scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in
            self?.advancePulses()
        }
    }

    private func addMarker(concept: ShadowConcept, position: SIMD3<Float>) {
        let dot = ModelEntity(
            mesh: .generateSphere(radius: dotRadius),
            materials: [UnlitMaterial(color: markerColor)]
        )
        dot.name = "Label: \(concept.rawValue)"
        dot.position = position
        dot.components.set(CollisionComponent(shapes: [.generateSphere(radius: tapTargetRadius)]))
        root.addChild(dot)
        dots.append(dot)

        let ringMesh = MeshResource.generatePlane(width: ringDiameter, height: ringDiameter)
        let ring = ModelEntity(mesh: ringMesh, materials: [ShadowAnnotationManager.ringMaterial(alpha: 1.0)])
        ring.name = "Pulse ring: \(concept.rawValue)"
        ring.position = position
        ring.components.set(BillboardComponent())
        root.addChild(ring)
        pulseRings.append(PulseRing(entity: ring, startTime: Date()))
    }

    private func advancePulses() {
        let now = Date()
        for pulse in pulseRings {
            let elapsed = now.timeIntervalSince(pulse.startTime).truncatingRemainder(dividingBy: pulseDuration)
            let t = Float(elapsed / pulseDuration)

            let scale = pulseStartScale + (pulseEndScale - pulseStartScale) * t
            pulse.entity.scale = SIMD3<Float>(repeating: scale)

            let alpha = 1.0 - t
            if var model = pulse.entity.components[ModelComponent.self] {
                model.materials = [ShadowAnnotationManager.ringMaterial(alpha: alpha)]
                pulse.entity.components[ModelComponent.self] = model
            }
        }
    }

    private static func ringMaterial(alpha: Float) -> UnlitMaterial {
        var material = UnlitMaterial()
        if let texture = cachedRingTexture ?? generateRingTexture() {
            cachedRingTexture = texture
            material.color = .init(tint: .white.withAlphaComponent(CGFloat(alpha)), texture: .init(texture))
        } else {
            material.color = .init(tint: .white.withAlphaComponent(CGFloat(alpha)))
        }
        material.blending = .transparent(opacity: .init(floatLiteral: alpha))
        return material
    }

    private static func generateRingTexture(size: CGFloat = 256, strokeWidthFraction: CGFloat = 0.1) -> TextureResource? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            context.cgContext.clear(rect)
            let lineWidth = size * strokeWidthFraction
            let ringRect = rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
            context.cgContext.setStrokeColor(UIColor.white.cgColor)
            context.cgContext.setLineWidth(lineWidth)
            context.cgContext.strokeEllipse(in: ringRect)
        }
        guard let cgImage = image.cgImage else { return nil }
        return try? TextureResource(image: cgImage, withName: nil, options: .init(semantic: .color))
    }

    private func shadowOffset(light: LightConfiguration, object: SIMD3<Float>, scale: Float) -> SIMD3<Float> {
        let lightDirection = SceneLightEntityFactory.forwardVector(
            yawDegrees: light.yawDegrees,
            pitchDegrees: light.pitchDegrees
        )
        guard let direction = ShadowGeometryCalculator.groundShadowDirection(lightDirection: lightDirection) else {
            return SIMD3<Float>(0, 0.02, 0.2)
        }
        return direction * scale + SIMD3<Float>(0, 0.025, 0)
    }
}
