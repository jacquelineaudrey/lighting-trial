import Foundation

struct SnapshotFeedback: Identifiable {
    let id = UUID()
    let isSuccess: Bool
    let message: String
}
