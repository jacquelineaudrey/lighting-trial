import RealityKit
import SwiftUI
import UIKit

/// Surface texture options for the placed learning object.
/// Ported from SpatialComposer's `MaterialTexture` model. Drop matching
/// image assets (`tex_marble`, `tex_wood`, `tex_metal`, `tex_grid`) into
/// Assets.xcassets to get real PBR textures — until then this falls back to
/// a flat-colored material so the feature never breaks the build.
struct MaterialTexture: Identifiable, Hashable {
    let id: String
    let name: String
    let assetName: String
    let previewSystemImage: String
    let isMetallic: Bool
    let roughness: Float

    static let defaultGrid = MaterialTexture(
        id: "grid", name: "Grid", assetName: "tex_grid",
        previewSystemImage: "grid", isMetallic: false, roughness: 0.6
    )

    static let library: [MaterialTexture] = [
        defaultGrid,
        MaterialTexture(id: "marble", name: "Marble", assetName: "tex_marble",
                         previewSystemImage: "square.on.square", isMetallic: false, roughness: 0.15),
        MaterialTexture(id: "wood", name: "Wood", assetName: "tex_wood",
                         previewSystemImage: "rectangle.grid.1x2", isMetallic: false, roughness: 0.5),
        MaterialTexture(id: "metal", name: "Brushed Metal", assetName: "tex_metal",
                         previewSystemImage: "circle.hexagongrid", isMetallic: true, roughness: 0.25)
    ]

    /// Builds a RealityKit material for this texture. Falls back to a flat
    /// SimpleMaterial if the texture asset hasn't been bundled yet.
    func makeMaterial() -> RealityKit.Material {
        if let cgImage = UIImage(named: assetName)?.cgImage,
           let texture = try? TextureResource.generate(from: cgImage, options: .init(semantic: .color)) {
            var material = PhysicallyBasedMaterial()
            material.baseColor = .init(texture: .init(texture))
            material.roughness = .init(floatLiteral: roughness)
            material.metallic = .init(floatLiteral: isMetallic ? 1.0 : 0.0)
            return material
        }
        return SimpleMaterial(color: .lightGray, roughness: .init(floatLiteral: roughness), isMetallic: isMetallic)
    }
}
