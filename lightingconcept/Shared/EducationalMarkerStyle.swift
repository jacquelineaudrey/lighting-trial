import RealityKit
import UIKit

/// Visual bersama untuk marker edukasi AR pada Level 1, 2, dan 3.
enum EducationalMarkerStyle {
    nonisolated enum SurfaceTone: Equatable, Sendable {
        case bright
        case medium
        case dark
    }

    struct Palette {
        let primary: UIColor
        let selected: UIColor
    }

    /// Palet awal aman untuk lantai abu-abu. Runtime akan menggantinya setelah
    /// estimator memperoleh sampel luminance lantai dari kamera.
    static let color = palette(for: .medium).primary
    static let selectedColor = palette(for: .medium).selected

    static let dotRadius: Float = 0.015
    static let ringDiameter: Float = 0.062
    static let tapTargetRadius: Float = 0.042
    static let ringTapTargetRadius: Float = 0.072
    static let connectorDashRadius: Float = 0.0036
    static let promptDotDiameter: Float = 0.042
    static let promptRingDiameter: Float = 0.082

    private static var cachedRingTexture: TextureResource?

    static func palette(for surfaceTone: SurfaceTone) -> Palette {
        switch surfaceTone {
        case .bright:
            // Indigo gelap tetap terbaca pada keramik atau lantai putih.
            Palette(
                primary: UIColor(red: 0.20, green: 0.08, blue: 0.72, alpha: 1),
                selected: UIColor(red: 0.88, green: 0.08, blue: 0.34, alpha: 1)
            )
        case .medium:
            // Kuning terang paling mudah dipisahkan dari lantai abu-abu.
            Palette(
                primary: UIColor(red: 1.0, green: 0.78, blue: 0.0, alpha: 1),
                selected: UIColor(red: 1.0, green: 0.16, blue: 0.48, alpha: 1)
            )
        case .dark:
            // Cyan terang memberi kontras tinggi pada lantai hitam atau gelap.
            Palette(
                primary: UIColor(red: 0.0, green: 0.90, blue: 1.0, alpha: 1),
                selected: UIColor(red: 1.0, green: 0.72, blue: 0.0, alpha: 1)
            )
        }
    }

    static func ringMaterial(alpha: Float, tint: UIColor? = nil) -> UnlitMaterial {
        let resolvedTint = tint ?? color
        var material = UnlitMaterial()
        if let texture = cachedRingTexture ?? generateRingTexture() {
            cachedRingTexture = texture
            material.color = .init(
                tint: resolvedTint.withAlphaComponent(CGFloat(alpha)),
                texture: .init(texture)
            )
        } else {
            material.color = .init(tint: resolvedTint.withAlphaComponent(CGFloat(alpha)))
        }
        material.blending = .transparent(opacity: .init(floatLiteral: alpha))
        return material
    }

    private static func generateRingTexture(
        size: CGFloat = 256,
        strokeWidthFraction: CGFloat = 0.13
    ) -> TextureResource? {
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
}
