import Foundation

struct ImportedModelConfiguration: Equatable {
    static let placeholderDimensions = SIMD3<Float>(repeating: 0.16)
    static let targetMaximumDimension: Float = 0.18

    let fileURL: URL
    let displayName: String
    var dimensions: SIMD3<Float> = placeholderDimensions

    var displayTypeName: String {
        fileURL.pathExtension.lowercased() == "reality"
            ? "Imported Reality"
            : "Imported USDZ"
    }
}
