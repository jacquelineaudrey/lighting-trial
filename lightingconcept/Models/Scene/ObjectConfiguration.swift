import Foundation

struct ObjectConfiguration: Identifiable, Equatable {
    let id: UUID
    var name: String
    var type: LearningObjectType
    var scale: Float
    var yawDegrees: Float
    var position: SIMD3<Float>
    var importedModel: ImportedModelConfiguration?

    var displayTypeName: String {
        importedModel?.displayTypeName ?? type.rawValue
    }

    var isImportedModel: Bool {
        importedModel != nil
    }

    var supportsYawRotation: Bool {
        isImportedModel || type.supportsYawRotation
    }

    static func defaultObject(
        index: Int = 1,
        type: LearningObjectType = .cube,
        position: SIMD3<Float> = .zero
    ) -> ObjectConfiguration {
        ObjectConfiguration(
            id: UUID(),
            name: "Object \(index)",
            type: type,
            scale: 1,
            yawDegrees: 0,
            position: position,
            importedModel: nil
        )
    }
}
