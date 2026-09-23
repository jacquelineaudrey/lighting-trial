import Foundation

struct SafetyProximityWarning: Equatable {
    let objectName: String
    let distanceMeters: Float

    // The distance is used for thresholding, but it is not shown in the dialog.
    // Treating a moving object as the same warning avoids refreshing SwiftUI on
    // every AR frame while the user remains near that object.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.objectName == rhs.objectName
    }

    var message: String {
        "Ada \(objectName) di dekatmu. Mundur sedikit ya!"
    }
}
