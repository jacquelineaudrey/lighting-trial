import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ARSceneViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isControlInspectorPresented = true
    @State private var isControlSheetPresented = true
    @State private var controlSheetDetent = PresentationDetent.medium

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                sceneCanvas
                    .inspector(isPresented: $isControlInspectorPresented) {
                        SceneControlPanel(viewModel: viewModel, isInspector: true)
                            .inspectorColumnWidth(min: 320, ideal: 380, max: 460)
                    }
                    .overlay(alignment: .topTrailing) {
                        if !isControlInspectorPresented {
                            Button("Show Controls", systemImage: "sidebar.right") {
                                isControlInspectorPresented = true
                            }
                            .labelStyle(.iconOnly)
                            .frame(minWidth: 44, minHeight: 44)
                            .background(.thinMaterial, in: Circle())
                            .padding()
                        }
                    }
            } else {
                sceneCanvas
                    .onAppear {
                        isControlSheetPresented = true
                    }
                    .sheet(isPresented: $isControlSheetPresented) {
                        SceneControlPanel(viewModel: viewModel)
                            .presentationDetents([.height(170), .medium, .large], selection: $controlSheetDetent)
                            .presentationDragIndicator(.visible)
                            .presentationBackground(.regularMaterial)
                            .presentationBackgroundInteraction(.enabled(upThrough: .height(170)))
                            .presentationContentInteraction(.scrolls)
                            .interactiveDismissDisabled()
                    }
            }
        }
        .alert(
            viewModel.selectedConcept?.rawValue ?? "Shadow Concept",
            isPresented: selectedConceptAlertBinding
        ) {
            Button("OK", role: .cancel) {
                viewModel.selectedConcept = nil
            }
        } message: {
            Text(viewModel.selectedConcept?.explanation ?? "")
        }
    }

    private var sceneCanvas: some View {
        ZStack(alignment: .top) {
            ARContainerView(viewModel: viewModel)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                if viewModel.isLiDARAvailable, !viewModel.isObjectPlaced {
                    LiDARScanProgressCard(viewModel: viewModel)
                } else {
                    StatusBanner(
                        text: viewModel.collisionWarning ?? viewModel.surfaceGuidanceText,
                        isWarning: viewModel.collisionWarning != nil
                    )
                }

                if viewModel.isObjectPlaced || viewModel.surfaceState == .placed {
                    InteractionModeControl(viewModel: viewModel)
                }
            }
            .padding(.top, 12)
            .padding(.horizontal)
        }
    }
}

private extension ContentView {
    var selectedConceptAlertBinding: Binding<Bool> {
        Binding {
            viewModel.selectedConcept != nil
        } set: { isPresented in
            if !isPresented {
                viewModel.selectedConcept = nil
            }
        }
    }
}

private struct InteractionModeControl: View {
    @ObservedObject var viewModel: ARSceneViewModel

    var body: some View {
        Picker("Interaction Mode", selection: $viewModel.interactionMode) {
            ForEach(InteractionMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 360)
        .padding(8)
        .background(.thinMaterial, in: Capsule())
        .accessibilityLabel("Interaction Mode")
    }
}

private struct StatusBanner: View {
    let text: String
    let isWarning: Bool

    var body: some View {
        Label(text, systemImage: isWarning ? "exclamationmark.triangle.fill" : "viewfinder")
            .font(.callout)
            .bold()
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.thinMaterial, in: Capsule())
            .accessibilityLabel(text)
    }
}

private struct LiDARScanProgressCard: View {
    @ObservedObject var viewModel: ARSceneViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("LiDAR Surface Scan", systemImage: "cube.transparent")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(viewModel.isReadyForPlacement ? "Ready" : "\(Int(viewModel.lidarPlacementProgress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: viewModel.lidarPlacementProgress)
                .tint(viewModel.isReadyForPlacement ? .green : .cyan)

            Text(viewModel.isReadyForPlacement
                 ? "Area siap. Tap meja atau permukaan datar untuk menaruh object."
                 : "Arahkan kamera perlahan ke meja, sisi benda, dan tepi permukaan. Area cyan adalah bagian yang sudah terbaca.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: 380)
    }
}
