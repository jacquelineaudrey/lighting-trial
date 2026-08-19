import RealityKit
import UIKit

enum CharacterGuideAsset: String {
    case lumiIdle, lumiPoint, lumiQuestion
    case lumiPointWink = "lumiPointwink"

    case bayoIdle, bayoPoint, bayoPointWink, bayoQuestion
}

/// Factory ECS untuk entity karakter dan bubble chat RealityKit.
/// Seluruh guide sengaja dibuat sebagai overlay AR:
/// - tidak membaca depth scene
/// - tidak menulis depth
/// - urutan rendering dikunci:
///   character < bubble < text
enum CharacterGuideFactory {

    private static let guideSortGroup = ModelSortGroup(depthPass: .postPass)

    private enum GuideRenderOrder {
        static let character: Int32 = 40
        static let bubble: Int32 = 41
        static let text: Int32 = 42
    }

    // MARK: - Character

    static func makeCharacter(
        asset: CharacterGuideAsset,
        width: Float = 0.42,
        height: Float = 0.58
    ) -> ModelEntity? {

        guard let texture = texture(for: asset) else {
            return nil
        }

        var material = UnlitMaterial()

        material.color = .init(
            tint: .white,
            texture: .init(texture)
        )

        material.blending = .transparent(opacity: 1.0)

        // IMPORTANT:
        // Guide harus selalu terlihat di depan object AR.
        material.readsDepth = false
        material.writesDepth = false

        let character = ModelEntity(
            mesh: .generatePlane(
                width: width,
                height: height
            ),
            materials: [material]
        )

        character.name = "Guide Character — \(asset.rawValue)"

        character.components.set(BillboardComponent())

        character.components.set(
            ModelSortGroupComponent(
                group: Self.guideSortGroup,
                order: GuideRenderOrder.character
            )
        )

        character.components.set(
            DynamicLightShadowComponent(
                castsShadow: false
            )
        )

        disableInteraction(on: character)

        return character
    }

    // MARK: - Speech Cloud

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

        // ============================================
        // BACKGROUND
        // ============================================

        var backgroundMaterial = UnlitMaterial()

        backgroundMaterial.color = .init(
            tint: UIColor.white.withAlphaComponent(0.95)
        )

        backgroundMaterial.blending = .transparent(
            opacity: 0.95
        )

        // Tidak boleh kena occlusion dari object AR.
        backgroundMaterial.readsDepth = false
        backgroundMaterial.writesDepth = false

        let background = ModelEntity(
            mesh: .generatePlane(
                width: width,
                height: height
            ),
            materials: [backgroundMaterial]
        )

        background.name = "Guide Speech Background"

        background.components.set(
            DynamicLightShadowComponent(
                castsShadow: false
            )
        )

        background.components.set(
            ModelSortGroupComponent(
                group: Self.guideSortGroup,
                order: GuideRenderOrder.bubble
            )
        )

        cloud.addChild(background)

        // ============================================
        // TEXT
        // ============================================

        let availableWidth = max(
            width - textHorizontalInset * 2,
            0.02
        )

        let availableHeight = max(
            height - textVerticalInset * 2,
            0.02
        )

        let mesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.001,
            font: .systemFont(
                ofSize: fontSize,
                weight: .medium
            ),
            containerFrame: CGRect(
                x: 0,
                y: 0,
                width: CGFloat(availableWidth),
                height: CGFloat(availableHeight)
            ),
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )

        var textMaterial = UnlitMaterial()

        textMaterial.color = .init(
            tint: .darkGray
        )

        // Text juga tidak membaca / menulis depth.
        textMaterial.readsDepth = false
        textMaterial.writesDepth = false

        let label = ModelEntity(
            mesh: mesh,
            materials: [textMaterial]
        )

        label.name = "Guide Speech Text"

        // Center text terhadap bubble.
        //
        // Tidak perlu mengandalkan Z besar untuk membuat text
        // berada di depan bubble karena ModelSortGroup sudah
        // mengunci draw order-nya.
        label.position = SIMD3<Float>(
            -mesh.bounds.center.x,
            -mesh.bounds.center.y,
            0.002
        )

        label.components.set(
            DynamicLightShadowComponent(
                castsShadow: false
            )
        )

        label.components.set(
            ModelSortGroupComponent(
                group: Self.guideSortGroup,
                order: GuideRenderOrder.text
            )
        )

        cloud.addChild(label)

        disableInteraction(on: cloud)

        return cloud
    }

    // MARK: - Interaction

    private static func disableInteraction(
        on entity: Entity
    ) {
        entity.components.remove(
            CollisionComponent.self
        )

        entity.components.remove(
            InputTargetComponent.self
        )

        for child in entity.children {
            disableInteraction(on: child)
        }
    }

    // MARK: - Texture

    private static func texture(
        for asset: CharacterGuideAsset
    ) -> TextureResource? {

        guard
            let image = UIImage(named: asset.rawValue),
            let cgImage = image.cgImage
        else {
            return nil
        }

        return try? TextureResource(
            image: cgImage,
            withName: asset.rawValue,
            options: .init(
                semantic: .color
            )
        )
    }
}
