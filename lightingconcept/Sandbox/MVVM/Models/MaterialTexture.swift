import SwiftUI

enum MaterialShadowBehavior: String, Hashable {
    case opaque
    case cutout
}

struct MaterialTextureColor: Hashable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    static func opaque(red: Double, green: Double, blue: Double) -> Self {
        Self(red: red, green: green, blue: blue, alpha: 1)
    }

    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}

/// Pure application data describing a selectable object material.
///
/// RealityKit materials, textures, procedural images, and renderer configuration
/// are deliberately not created here. That work belongs to the ECS scene systems.
struct MaterialTexture: Identifiable, Hashable {
    let id: String
    let name: String
    let assetName: String
    let previewSystemImage: String
    let isMetallic: Bool
    let roughness: Float
    let fallbackColor: MaterialTextureColor
    let shadowBehavior: MaterialShadowBehavior

    static let defaultGrid = MaterialTexture(
        id: "grid", name: "Grid", assetName: "tex_grid",
        previewSystemImage: "grid", isMetallic: false, roughness: 0.6,
        fallbackColor: .opaque(red: 0.74, green: 0.74, blue: 0.74),
        shadowBehavior: .opaque
    )

    static let library: [MaterialTexture] = [
        defaultGrid,
        MaterialTexture(
            id: "marble", name: "Marble", assetName: "tex_marble",
            previewSystemImage: "square.on.square", isMetallic: false, roughness: 0.15,
            fallbackColor: .opaque(red: 0.86, green: 0.88, blue: 0.9),
            shadowBehavior: .opaque
        ),
        MaterialTexture(
            id: "wood", name: "Wood", assetName: "tex_wood",
            previewSystemImage: "rectangle.grid.1x2", isMetallic: false, roughness: 0.5,
            fallbackColor: .opaque(red: 0.62, green: 0.42, blue: 0.24),
            shadowBehavior: .opaque
        ),
        MaterialTexture(
            id: "metal", name: "Brushed Metal", assetName: "tex_metal",
            previewSystemImage: "circle.hexagongrid", isMetallic: true, roughness: 0.25,
            fallbackColor: .opaque(red: 0.58, green: 0.62, blue: 0.66),
            shadowBehavior: .opaque
        ),
        MaterialTexture(
            id: "cutout", name: "Cutout", assetName: "tex_cutout",
            previewSystemImage: "circle.grid.cross", isMetallic: false, roughness: 0.65,
            fallbackColor: .opaque(red: 0.88, green: 0.82, blue: 0.58),
            shadowBehavior: .cutout
        )
    ]

    var shadowExplanation: String {
        switch shadowBehavior {
        case .opaque:
            "Opaque material blocks light. Shadow shape mainly follows the object geometry."
        case .cutout:
            "Cutout material uses an alpha mask visually. If supported by the renderer, holes can reduce the caster surface; otherwise the visible shadow still follows the mesh silhouette."
        }
    }
}
