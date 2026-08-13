import Foundation
import RealityKit

/// Pure state for a scene object.
///
/// No Tasks, closures, renderer references, or mutation methods are stored here.
/// Runtime loading is owned by `SceneObjectSystem`; persistent object state lives here.
struct SceneObjectComponent: Component {
    var configuration: ObjectConfiguration
    var sourceKey: String

    init(
        configuration: ObjectConfiguration,
        sourceKey: String
    ) {
        self.configuration = configuration
        self.sourceKey = sourceKey
    }
}
