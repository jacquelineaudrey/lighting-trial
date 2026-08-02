import RealityKit
import SwiftUI
import UIKit

extension Color {
    var uiColor: UIColor {
        UIColor(self)
    }
}

extension SIMD3<Float> {
    var horizontalLength: Float {
        sqrt(x * x + z * z)
    }
}

extension Float {
    var degreesToRadians: Float {
        self * .pi / 180
    }

    var radiansToDegrees: Float {
        self * 180 / .pi
    }
}

func clamped(_ value: Float, _ lower: Float, _ upper: Float) -> Float {
    min(max(value, lower), upper)
}
