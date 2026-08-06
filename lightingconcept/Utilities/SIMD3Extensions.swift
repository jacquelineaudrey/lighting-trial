import Foundation

extension SIMD3<Float> {
    var horizontalLength: Float {
        sqrt(x * x + z * z)
    }
}
