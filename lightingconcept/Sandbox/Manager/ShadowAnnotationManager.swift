import RealityKit
import Combine
import UIKit

final class ShadowAnnotationManager {
    private let root = Entity()
    private var dots: [ModelEntity] = []
    private var connectorDashes: [ModelEntity] = []
    private var pulseRings: [PulseRing] = []
    private var updateSubscription: Cancellable?
    private var lastPulseUpdate = Date.distantPast
    private var lastMarkerSignature: MarkerSignature?
    private static var cachedRingTexture: TextureResource?

    // Marker yang sedang dipilih pemain. Marker ini diberi warna MERAH (dot &
    // ring), sisanya tetap putih — meniru perilaku white mark di Level 1 yang
    // berubah merah saat ditekan.
    private(set) var selectedConcept: ShadowConcept?
    private var dotsByConcept: [ShadowConcept: ModelEntity] = [:]

    private let dotRadius: Float = 0.004
    private let tapTargetRadius: Float = 0.01
    private let ringDiameter: Float = 0.01
    private let pulseStartScale: Float = 1.0
    private let pulseEndScale: Float = 2.6
    private let pulseDuration: TimeInterval = 1.3
    private let markerColor: UIColor = .white
    private let selectedColor: UIColor = .systemRed

    private struct PulseRing {
        let entity: ModelEntity
        let startTime: Date
        let concept: ShadowConcept
    }

    private struct MarkerSignature: Equatable {
        let visible: Bool
        let objectType: LearningObjectType
        let objectPosition: SIMD3<Float>
        let objectHeight: Float
        let worldLightDirection: SIMD3<Float>
        let hiddenConcepts: Set<ShadowConcept>
    }

    func attach(to anchor: AnchorEntity) {
        if root.parent == nil {
            anchor.addChild(root)
        }
        subscribeToUpdatesIfNeeded()
    }

    func clear() {
        clearRenderedMarkers()
        lastMarkerSignature = nil
    }

    private func clearRenderedMarkers() {
        dots.forEach { $0.removeFromParent() }
        dots.removeAll()
        dotsByConcept.removeAll()
        connectorDashes.forEach { $0.removeFromParent() }
        connectorDashes.removeAll()
        pulseRings.forEach { $0.entity.removeFromParent() }
        pulseRings.removeAll()
    }

    /// Tandai marker terpilih menjadi merah (dot langsung; ring menyusul lewat
    /// `advancePulses`). Kirim `nil` untuk mengembalikan semua ke putih.
    func setSelected(_ concept: ShadowConcept?) {
        selectedConcept = concept
        for (markerConcept, dot) in dotsByConcept {
            let color = markerConcept == concept ? selectedColor : markerColor
            dot.model?.materials = [UnlitMaterial(color: color)]
        }
    }

    func update(
        visible: Bool,
        objectType: LearningObjectType,
        objectPosition: SIMD3<Float>,
        objectHeight: Float,
        // Arah cahaya dalam WORLD SPACE (bukan local space lampu). Caller
        // (`ARSceneCoordinator.updateEducationalOverlays`) sudah mengubahnya
        // lewat anchor transform sebelum diteruskan ke sini — lihat catatan
        // di `shadowOffset(worldLightDirection:...)`.
        worldLightDirection: SIMD3<Float>,
        hiddenConcepts: Set<ShadowConcept> = []
    ) {
        let signature = MarkerSignature(
            visible: visible,
            objectType: objectType,
            objectPosition: objectPosition,
            objectHeight: objectHeight,
            worldLightDirection: worldLightDirection,
            hiddenConcepts: hiddenConcepts
        )
        // Keep the same RealityKit marker entities alive while the learner
        // advances dialogue/progress. This preserves the working tap behavior
        // from the first shadow-search phase and avoids rebuilding meshes,
        // collision shapes, and pulse materials on every SwiftUI refresh.
        guard signature != lastMarkerSignature else { return }
        clearRenderedMarkers()
        lastMarkerSignature = signature
        guard visible else { return }

        subscribeToUpdatesIfNeeded()

        let concepts: [(ShadowConcept, SIMD3<Float>)]
        if objectType == .cube {
            concepts = [
                (.lightSide, objectPosition + SIMD3<Float>(-0.08, objectHeight * 0.72, 0)),
                (.shadowSide, objectPosition + SIMD3<Float>(0.08, objectHeight * 0.5, 0)),
                (.castShadow, objectPosition + shadowOffset(worldLightDirection: worldLightDirection, scale: 0.24)),
                (.reflectedLight, objectPosition + SIMD3<Float>(0, objectHeight * 0.28, 0.08))
            ]
        } else {
            concepts = [
                (.lightSide, objectPosition + SIMD3<Float>(-0.08, objectHeight * 0.68, 0)),
                (.shadowSide, objectPosition + SIMD3<Float>(0.08, objectHeight * 0.52, 0)),
                (.castShadow, objectPosition + shadowOffset(worldLightDirection: worldLightDirection, scale: 0.24)),
                (.reflectedLight, objectPosition + SIMD3<Float>(0.04, objectHeight * 0.34, 0.06))
            ]
        }

        for (concept, position) in concepts where !hiddenConcepts.contains(concept) {
            addMarker(concept: concept, position: position, objectPosition: objectPosition)
        }

        // Kalau ada marker yang sedang dipilih, pertahankan warna merahnya
        // setelah rebuild (mis. saat progress dialog berubah).
        setSelected(selectedConcept)
    }

    private func subscribeToUpdatesIfNeeded() {
        guard updateSubscription == nil, let scene = root.scene else { return }
        updateSubscription = scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in
            self?.advancePulses()
        }
    }

    private func addMarker(
        concept: ShadowConcept,
        position: SIMD3<Float>,
        objectPosition: SIMD3<Float>
    ) {
        // Float each marker approximately 15 cm away from the object, then
        // connect it back with a small dotted leader line. This avoids the
        // marker visually merging into the object's surface.
        let offset = position - objectPosition
        let direction = simd_length(offset) > 0.0001
            ? simd_normalize(offset)
            : SIMD3<Float>(0, 1, 0)
        let markerPosition = position + direction * 0.15
        addDottedConnector(from: position, to: markerPosition)

        let dot = ModelEntity(
            mesh: .generateSphere(radius: dotRadius),
            materials: [UnlitMaterial(color: markerColor)]
        )
        dot.name = "Label: \(concept.rawValue)"
        dot.position = markerPosition
        dot.components.set(CollisionComponent(shapes: [.generateSphere(radius: tapTargetRadius)]))
        dot.components.set(InputTargetComponent())
        root.addChild(dot)
        dots.append(dot)
        dotsByConcept[concept] = dot

        let ringMesh = MeshResource.generatePlane(width: ringDiameter, height: ringDiameter)
        let ring = ModelEntity(mesh: ringMesh, materials: [ShadowAnnotationManager.ringMaterial(alpha: 1.0)])
        // The expanding ring is what learners can see and aim for. Give it the
        // same label identifier and a larger collision volume as the dot so a
        // tap opens the SwiftUI explanation during the first Level 3 task.
        ring.name = "Label: \(concept.rawValue)"
        ring.position = markerPosition
        ring.components.set(BillboardComponent())
        ring.components.set(CollisionComponent(shapes: [.generateSphere(radius: tapTargetRadius * 2.5)]))
        ring.components.set(InputTargetComponent())
        root.addChild(ring)
        pulseRings.append(PulseRing(entity: ring, startTime: Date(), concept: concept))
    }

    private func addDottedConnector(from start: SIMD3<Float>, to end: SIMD3<Float>) {
        let dashMaterial = UnlitMaterial(color: UIColor.white.withAlphaComponent(0.75))
        for fraction: Float in [0.25, 0.5, 0.75] {
            let dash = ModelEntity(
                mesh: .generateSphere(radius: 0.0018),
                materials: [dashMaterial]
            )
            dash.position = start + (end - start) * fraction
            root.addChild(dash)
            connectorDashes.append(dash)
        }
    }

    private func advancePulses() {
        let now = Date()
        // The markers are decorative. Eight updates per second keeps the
        // pulse readable while avoiding repeated material allocations that can
        // compete with AR tracking on a real device.
        guard now.timeIntervalSince(lastPulseUpdate) >= (1.0 / 8.0) else { return }
        lastPulseUpdate = now
        for pulse in pulseRings {
            let elapsed = now.timeIntervalSince(pulse.startTime).truncatingRemainder(dividingBy: pulseDuration)
            let t = Float(elapsed / pulseDuration)

            let scale = pulseStartScale + (pulseEndScale - pulseStartScale) * t
            pulse.entity.scale = SIMD3<Float>(repeating: scale)

            let alpha = 1.0 - t
            let tint = pulse.concept == selectedConcept ? selectedColor : markerColor
            if var model = pulse.entity.components[ModelComponent.self] {
                model.materials = [ShadowAnnotationManager.ringMaterial(alpha: alpha, tint: tint)]
                pulse.entity.components[ModelComponent.self] = model
            }
        }
    }

    private static func ringMaterial(alpha: Float, tint: UIColor = .white) -> UnlitMaterial {
        var material = UnlitMaterial()
        if let texture = cachedRingTexture ?? generateRingTexture() {
            cachedRingTexture = texture
            material.color = .init(tint: tint.withAlphaComponent(CGFloat(alpha)), texture: .init(texture))
        } else {
            material.color = .init(tint: tint.withAlphaComponent(CGFloat(alpha)))
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

    /// PENTING: `worldLightDirection` HARUS sudah dalam world space (sudah
    /// melewati transform anchor scene), bukan local space lampu.
    ///
    /// Sebelumnya fungsi ini menghitung ulang arah cahaya sendiri lewat
    /// `SceneLightSystem.forwardVector(yaw, pitch)`, yang hanya berupa
    /// arah LOCAL relatif ke entity lampu — tanpa memperhitungkan rotasi
    /// anchor scene tempat lampu itu ditempel. Ini tidak masalah selama
    /// anchor scene tidak berotasi (identity), tapi jadi salah begitu anchor
    /// punya rotasi non-identity — misalnya di Level 4, yang menaruh scene
    /// otomatis dari hasil raycast permukaan (`ARSceneCoordinator.placeScene`),
    /// dan `worldTransform` hasil raycast plane ARKit umumnya TIDAK cuma
    /// translasi, tapi ikut rotasi mengikuti orientasi bidang yang terdeteksi.
    /// Akibatnya titik "castShadow" annotation ini bisa menunjuk ke arah yang
    /// tidak cocok dengan bayangan asli yang dirender RealityKit (yang selalu
    /// benar karena dihitung dari transform world entity yang sebenarnya).
    private func shadowOffset(worldLightDirection: SIMD3<Float>, scale: Float) -> SIMD3<Float> {
        guard let direction = ShadowGeometryCalculator.groundShadowDirection(lightDirection: worldLightDirection) else {
            return SIMD3<Float>(0, 0.02, 0.2)
        }
        return direction * scale + SIMD3<Float>(0, 0.025, 0)
    }
}
