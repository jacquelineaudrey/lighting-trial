import Foundation

enum ImportedModelStore {
    nonisolated static func copyIntoTemporaryStorage(from sourceURL: URL) throws -> URL {
        let hasSecurityScopedAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScopedAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileManager = FileManager.default
        let fileExtension = sourceURL.pathExtension.lowercased()
        guard fileExtension == "usdz" || fileExtension == "reality" else {
            throw CocoaError(.fileReadUnsupportedScheme)
        }

        let importDirectory = fileManager.temporaryDirectory
            .appending(path: "ImportedModels", directoryHint: .isDirectory)
        try fileManager.createDirectory(
            at: importDirectory,
            withIntermediateDirectories: true
        )

        let destinationURL = importDirectory.appending(
            path: "\(UUID().uuidString).\(fileExtension)",
            directoryHint: .notDirectory
        )
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }
}
