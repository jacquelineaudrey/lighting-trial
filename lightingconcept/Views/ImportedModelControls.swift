import SwiftUI
import UniformTypeIdentifiers

struct ImportedModelControls: View {
    @ObservedObject var viewModel: ARSceneViewModel
    @State private var isFileImporterPresented = false

    private static let appleModelGalleryURL = URL(
        string: "https://developer.apple.com/quick-look-gallery/"
    )!

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Apple 3D Models")
                .font(.headline)

            Text("Preview and download a USDZ or Reality model from Apple’s gallery, then import it from Files.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ViewThatFits {
                HStack(spacing: 8) {
                    galleryLink
                    importButton
                }

                VStack(spacing: 8) {
                    galleryLink
                    importButton
                }
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.usdz, .realityFile],
            allowsMultipleSelection: true,
            onCompletion: handleImportResult
        )
    }

    private var galleryLink: some View {
        Link(destination: Self.appleModelGalleryURL) {
            Label("Browse Gallery", systemImage: "safari")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
    }

    private var importButton: some View {
        Button {
            isFileImporterPresented = true
        } label: {
            if viewModel.isImportingModel {
                HStack {
                    ProgressView()
                    Text("Importing…")
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            } else {
                Label("Import Model", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.isImportingModel)
        .accessibilityLabel(viewModel.isImportingModel ? "Importing 3D model" : "Import 3D model")
    }

    private func handleImportResult(_ result: Result<[URL], any Error>) {
        switch result {
        case .success(let urls):
            viewModel.importModels(from: urls)
        case .failure(let error):
            viewModel.modelImportFailure = ModelImportFailure(message: error.localizedDescription)
        }
    }
}
