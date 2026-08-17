import RealityKit
import UIKit

enum CharacterGuideAsset: String {
    case lumiIdle, lumiPoint, lumiQuestion
    case lumiPointWink = "lumiPointwink"
    case bayoIdle, bayoPoint, bayoPointWink, bayoQuestion
}

/// Factory ECS untuk entity karakter dan bubble chat RealityKit. Controller
/// level hanya mengatur state/fase; asset dan material dibuat di satu tempat.
enum CharacterGuideFactory {
    static func makeCharacter(
        asset: CharacterGuideAsset,
        width: Float = 0.42,
        height: Float = 0.58
    ) -> ModelEntity? {
        guard let texture = texture(for: asset) else { return nil }
        var material = UnlitMaterial()
        material.color = .init(tint: .white, texture: .init(texture))
        material.blending = .transparent(opacity: 1.0)

        let character = ModelEntity(
            mesh: .generatePlane(width: width, height: height),
            materials: [material]
        )
        character.name = "Guide Character — \(asset.rawValue)"
        character.components.set(BillboardComponent())
        character.components.set(DynamicLightShadowComponent(castsShadow: false))
        return character
    }

    static func makeSpeechCloud(
        text: String,
        width: Float = 0.84,
        height: Float = 0.34,
        fontSize: CGFloat = 0.036,
        textHorizontalInset: Float = 0.10,
        textVerticalInset: Float = 0.09
    ) -> Entity {
        let cloud = Entity()
        cloud.name = "Guide Speech Cloud"
        cloud.components.set(BillboardComponent())

        var backgroundMaterial = UnlitMaterial()
        backgroundMaterial.color = .init(tint: UIColor.white.withAlphaComponent(0.95))
        backgroundMaterial.blending = .transparent(opacity: 0.95)
        let background = ModelEntity(
            mesh: .generatePlane(width: width, height: height),
            materials: [backgroundMaterial]
        )
        background.components.set(DynamicLightShadowComponent(castsShadow: false))
        cloud.addChild(background)

        let mesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: fontSize, weight: .medium),
            containerFrame: CGRect(
                x: 0,
                y: 0,
                width: CGFloat(max(width - textHorizontalInset, 0.02)),
                height: CGFloat(max(height - textVerticalInset, 0.02))
            ),
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        var textMaterial = UnlitMaterial()
        textMaterial.color = .init(tint: .darkGray)
        let label = ModelEntity(mesh: mesh, materials: [textMaterial])
        label.position = SIMD3<Float>(-mesh.bounds.center.x, -mesh.bounds.center.y, 0.002)
        label.components.set(DynamicLightShadowComponent(castsShadow: false))
        cloud.addChild(label)
        return cloud
    }

    private static func texture(for asset: CharacterGuideAsset) -> TextureResource? {
        guard let image = UIImage(named: asset.rawValue), let cgImage = image.cgImage else { return nil }
        return try? TextureResource(
            image: cgImage,
            withName: asset.rawValue,
            options: .init(semantic: .color)
        )
    }
}
