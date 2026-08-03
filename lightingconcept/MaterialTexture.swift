import RealityKit
import SwiftUI
import UIKit

enum MaterialShadowBehavior: String, Hashable {
    // Opaque: material menutup cahaya penuh, jadi bayangan terutama mengikuti bentuk mesh.
    case opaque

    // Translucent: object terlihat tembus cahaya, tetapi dynamic shadow RealityKit
    // di iOS belum selalu menghitung shadow semi-transparan secara fisik.
    case translucent

    // Cutout: material memakai alpha mask visual. Jika renderer mendukung, bagian
    // transparan bisa memengaruhi caster; jika tidak, shadow tetap mengikuti mesh.
    case cutout
}

/// Model data untuk pilihan material object.
/// Jika asset texture dengan nama `assetName` ada di Assets.xcassets, texture itu
/// dipakai. Jika tidak ada, app membuat texture procedural supaya prototype tetap
/// bisa jalan tanpa file gambar tambahan.
struct MaterialTexture: Identifiable, Hashable {
    let id: String
    let name: String
    let assetName: String
    let previewSystemImage: String
    let isMetallic: Bool
    let roughness: Float
    let fallbackColor: UIColor
    let shadowBehavior: MaterialShadowBehavior

    static let defaultGrid = MaterialTexture(
        id: "grid", name: "Grid", assetName: "tex_grid",
        previewSystemImage: "grid", isMetallic: false, roughness: 0.6,
        fallbackColor: UIColor(white: 0.74, alpha: 1),
        shadowBehavior: .opaque
    )

    static let library: [MaterialTexture] = [
        defaultGrid,
        MaterialTexture(id: "marble", name: "Marble", assetName: "tex_marble",
                         previewSystemImage: "square.on.square", isMetallic: false, roughness: 0.15,
                         fallbackColor: UIColor(red: 0.86, green: 0.88, blue: 0.9, alpha: 1),
                         shadowBehavior: .opaque),
        MaterialTexture(id: "wood", name: "Wood", assetName: "tex_wood",
                         previewSystemImage: "rectangle.grid.1x2", isMetallic: false, roughness: 0.5,
                         fallbackColor: UIColor(red: 0.62, green: 0.42, blue: 0.24, alpha: 1),
                         shadowBehavior: .opaque),
        MaterialTexture(id: "metal", name: "Brushed Metal", assetName: "tex_metal",
                         previewSystemImage: "circle.hexagongrid", isMetallic: true, roughness: 0.25,
                         fallbackColor: UIColor(red: 0.58, green: 0.62, blue: 0.66, alpha: 1),
                         shadowBehavior: .opaque),
        MaterialTexture(id: "frosted", name: "Frosted", assetName: "tex_frosted",
                         previewSystemImage: "circle.dotted", isMetallic: false, roughness: 0.9,
                         fallbackColor: UIColor(red: 0.72, green: 0.90, blue: 1.0, alpha: 1),
                         shadowBehavior: .translucent),
        MaterialTexture(id: "cutout", name: "Cutout", assetName: "tex_cutout",
                         previewSystemImage: "circle.grid.cross", isMetallic: false, roughness: 0.65,
                         fallbackColor: UIColor(red: 0.88, green: 0.82, blue: 0.58, alpha: 1),
                         shadowBehavior: .cutout)
    ]

    /// Membuat material RealityKit dari texture asset atau texture procedural.
    /// PBR dipakai supaya roughness/metallic tetap bereaksi terhadap virtual light.
    func makeMaterial() -> RealityKit.Material {
        let image = UIImage(named: assetName) ?? proceduralImage()
        if let cgImage = image.cgImage,
           let texture = try? TextureResource(image: cgImage, withName: assetName, options: .init(semantic: .color)) {
            var material = PhysicallyBasedMaterial()
            material.baseColor = .init(texture: .init(texture))
            material.roughness = .init(floatLiteral: roughness)
            material.metallic = .init(floatLiteral: isMetallic ? 1.0 : 0.0)
            applyTransparency(to: &material)
            return material
        }
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: fallbackColor)
        material.roughness = .init(floatLiteral: roughness)
        material.metallic = .init(floatLiteral: isMetallic ? 1.0 : 0.0)
        applyTransparency(to: &material)
        return material
    }

    var shadowExplanation: String {
        switch shadowBehavior {
        case .opaque:
            return "Opaque material blocks light. Shadow shape mainly follows the object geometry."
        case .translucent:
            return "Translucent material shows the object as semi-transparent. RealityKit may still cast an opaque dynamic shadow depending on device/SDK."
        case .cutout:
            return "Cutout material uses an alpha mask visually. If supported by the renderer, holes can reduce the caster surface; otherwise the visible shadow still follows the mesh silhouette."
        }
    }

    private func applyTransparency(to material: inout PhysicallyBasedMaterial) {
        switch shadowBehavior {
        case .opaque:
            material.blending = .opaque
        case .translucent:
            // Opacity 0.48 membuat object terlihat seperti kaca/plastik buram.
            // Catatan: ini terutama efek visual object; shadow dinamis dapat tetap opaque.
            material.blending = .transparent(opacity: .init(floatLiteral: 0.48))
        case .cutout:
            // Alpha mask: putih = terlihat, hitam = bolong. opacityThreshold membuat
            // transisi menjadi hard cutout, bukan semi-transparan bertahap.
            if let cgImage = proceduralOpacityImage().cgImage,
               let opacityTexture = try? TextureResource(image: cgImage, withName: "\(assetName)_opacity", options: .init(semantic: .color)) {
                material.blending = .transparent(opacity: .init(scale: 1.0, texture: .init(opacityTexture)))
                material.opacityThreshold = 0.55
            } else {
                material.blending = .transparent(opacity: .init(floatLiteral: 0.72))
            }
        }
    }

    private func proceduralImage(size: Int = 256) -> UIImage {
        // Texture procedural sederhana untuk membedakan bahan tanpa third-party asset.
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            fallbackColor.setFill()
            context.fill(rect)

            switch id {
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
                    UIColor(white: 1.0, alpha: alpha).setFill()
                    context.fill(CGRect(x: 0, y: index, width: size, height: 1))
                }
                UIColor(white: 0.35, alpha: 0.10).setFill()
                context.fill(CGRect(x: 0, y: 0, width: size, height: size))
            case "frosted":
                UIColor.white.withAlphaComponent(0.34).setFill()
                for index in 0..<36 {
                    let x = CGFloat((index * 37) % size)
                    let y = CGFloat((index * 61) % size)
                    context.fill(CGRect(x: x, y: y, width: 5, height: 5))
                }
            case "cutout":
                UIColor(red: 0.52, green: 0.42, blue: 0.18, alpha: 0.6).setFill()
                for y in stride(from: 18, to: size, by: 48) {
                    for x in stride(from: 18, to: size, by: 48) {
                        context.cgContext.fillEllipse(in: CGRect(x: x, y: y, width: 20, height: 20))
                    }
                }
            default:
                break
            }
        }
    }

    private func proceduralOpacityImage(size: Int = 256) -> UIImage {
        // Mask khusus material Cutout. Lubang hitam dibuat periodik agar developer
        // mudah melihat apakah renderer menghormati alpha mask pada object.
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: size, height: size))
            UIColor.black.setFill()
            for y in stride(from: 20, to: size, by: 48) {
                for x in stride(from: 20, to: size, by: 48) {
                    context.cgContext.fillEllipse(in: CGRect(x: x, y: y, width: 24, height: 24))
                }
            }
        }
    }

    func makeReceiverMaterial(alpha: CGFloat = 0.34) -> RealityKit.Material {
        let color = fallbackColor.withAlphaComponent(alpha)
        return SimpleMaterial(color: color, roughness: .init(floatLiteral: roughness), isMetallic: isMetallic)
    }
}
