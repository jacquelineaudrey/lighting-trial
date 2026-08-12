import SwiftUI

struct SceneControlPanel: View {
    @ObservedObject var viewModel: ARSceneViewModel
    var isInspector = false
    @State private var selectedTab = ControlTab.object

    var body: some View {
        VStack(spacing: 8) {
            Picker("Controls", selection: $selectedTab) {
                ForEach(ControlTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.symbol).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 12)

            Form {
                Section(selectedTab.title) {
                    switch selectedTab {
                    case .object:
                        objectControls
                    case .light:
                        lightControls
                    case .learn:
                        learnControls
                    case .scene:
                        sceneControls
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .alert(item: $viewModel.modelImportFailure) { failure in
            Alert(
                title: Text("Couldn’t Import 3D Model"),
                message: Text(failure.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var objectControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Active Object")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Menu {
                    Picker("Active Object", selection: $viewModel.selectedObjectID) {
                        ForEach(viewModel.objects) { object in
                            Text("\(object.name) — \(object.displayTypeName)")
                                .tag(object.id)
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "cube.transparent")
                            .font(.title3)
                            .frame(width: 32, height: 32)
                            .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.selectedObject.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(viewModel.selectedObject.displayTypeName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 8)

                        Text("\(viewModel.objects.count)")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary, in: Capsule())

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .accessibilityLabel("Active Object")
                .accessibilityValue(
                    "\(viewModel.selectedObject.name), \(viewModel.selectedObject.displayTypeName), \(viewModel.objects.count) objects"
                )

                Divider()

                HStack(spacing: 8) {
                    Button("Add Object", systemImage: "plus", action: viewModel.addObject)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .buttonStyle(.bordered)

                    Button("Remove", systemImage: "trash", action: viewModel.removeSelectedObject)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .buttonStyle(.bordered)
                        .disabled(viewModel.objects.count <= 1)
                }
            }
            .padding(10)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))

            ImportedModelControls(viewModel: viewModel)

            ObjectShapePreviewPicker(
                selection: $viewModel.selectedObjectType,
                showsSelection: !viewModel.selectedObject.isImportedModel
            )

            Picker("Surface Material", selection: selectedTextureBinding) {
                ForEach(MaterialTexture.library) { texture in
                    Label(texture.name, systemImage: texture.previewSystemImage).tag(texture)
                }
            }
            .pickerStyle(.menu)

            Text(viewModel.selectedTexture.shadowExplanation)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            sliderRow("Object Size", value: $viewModel.objectScale, range: 0.35...1.6, step: 0.05, suffix: "x")

            if viewModel.selectedObject.supportsYawRotation {
                sliderRow("Object Rotation", value: $viewModel.objectYawDegrees, range: -180...180, step: 1, suffix: "deg")
            }

        }
        .padding(.vertical, 6)
    }

    private var lightControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Shadow Lights \(viewModel.lights.count)/3")
                    .font(.caption.weight(.semibold))

                Picker("Selected Light", selection: $viewModel.selectedLightID) {
                    ForEach(viewModel.lights) { light in
                        Text(light.name).tag(light.id)
                    }
                }

                HStack(spacing: 12) {
                    Button(action: viewModel.addLight) {
                        Text("Add Light")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(viewModel.lights.count >= 3)

                    Button(role: .destructive, action: viewModel.removeSelectedLight) {
                        Text("Remove")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(viewModel.lights.count <= 1)
                }
                .buttonStyle(.bordered)
            }

            Picker("Light Type", selection: selectedLightTypeBinding) {
                ForEach(LearningLightType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)

            ColorPicker("Colour", selection: selectedLightColorBinding, supportsOpacity: false)

            sliderRow("Intensity", value: selectedIntensityBinding, range: 100...6000, step: 50, suffix: "lm")
            sliderRow("Height", value: selectedHeightBinding, range: -0.25...1.2, step: 0.01, suffix: "m")
            sliderRow("X Position", value: selectedXBinding, range: -0.9...0.9, step: 0.01, suffix: "m")
            sliderRow("Z Position", value: selectedZBinding, range: -0.9...0.9, step: 0.01, suffix: "m")

            if viewModel.selectedLight.type == .spot {
                Picker("Beam Spread", selection: selectedBeamBinding) {
                    ForEach(BeamSpreadPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
            } else {
                Text("Point light changes object lighting, but this RealityKit SDK only exposes dynamic cast shadows for Spot and Directional lights. Use Spot for visible overlapping shadows.")
                    .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var learnControls: some View {
        VStack(alignment: .leading, spacing: 18) {
            controlGroup("Guides") {
                toggleRow("Light Direction", isOn: $viewModel.showLightDirection)
                toggleRow("Light Rays", isOn: $viewModel.showLightRays)
                toggleRow("Ground Projection", isOn: $viewModel.showGroundProjection)
            }

            controlGroup("Geometry") {
                toggleRow("Projection Lines", isOn: $viewModel.showProjectionLines)
                Text("Shows how rays from the selected light pass through cube corners and meet the ground.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            controlGroup("Annotations") {
                toggleRow("Shadow Labels", isOn: $viewModel.showShadowLabels)
                toggleRow("Shadow Information", isOn: $viewModel.showShadowInformation)
            }

            if viewModel.showShadowInformation {
                ShadowInformationPanel(info: viewModel.shadowInfo)
            }
        }
        .padding(.vertical, 6)
    }

    private func controlGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .padding(.vertical, 6)
    }

    private var sceneControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                viewModel.resetScene()
            } label: {
                Text("Reset Virtual Scene")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            Text("Removes the placed object, shadow receiver, labels, and light markers, then lets you place the scene again without restarting AR tracking.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button {
                viewModel.rescanSurface()
            } label: {
                Text("Re-scan Surface")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Text("Restarts AR tracking and surface detection. Use this when the table/floor alignment or LiDAR mesh feels wrong.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("On LiDAR devices, RealityKit uses scene-understanding geometry for real-world lighting interaction. Other devices use a faint flat receiver fallback.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Button {
                viewModel.toggleFreeze()
            } label: {
                Text(viewModel.isViewFrozen ? "Resume AR View" : "Freeze AR View")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                viewModel.captureSnapshot()
            } label: {
                Text(viewModel.isSavingSnapshot ? "Saving…" : "Save to Photos")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.isViewFrozen || viewModel.isSavingSnapshot)

            Text("Freeze pauses the camera feed so you can capture the current lighting and shadow, then save it straight to your Photos gallery.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .alert(item: $viewModel.snapshotFeedback) { feedback in
            Alert(
                title: Text(feedback.isSuccess ? "Saved" : "Couldn't Save"),
                message: Text(feedback.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func sliderRow(_ title: String, value: Binding<Float>, range: ClosedRange<Float>, step: Float, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            let formattedValue = String(format: suffix == "m" ? "%.2f" : "%.1f", value.wrappedValue)
            HStack {
                Text(title)
                Spacer()
                Text("\(formattedValue) \(suffix)")
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
        }
        .font(.caption)
        .padding(.vertical, 4)
    }

    private var selectedLightTypeBinding: Binding<LearningLightType> {
        Binding {
            viewModel.selectedLight.type
        } set: { value in
            viewModel.updateSelectedLight { $0.type = value }
        }
    }

    private var selectedLightColorBinding: Binding<Color> {
        Binding {
            viewModel.selectedLight.color
        } set: { value in
            viewModel.updateSelectedLight { $0.color = value }
        }
    }

    private var selectedIntensityBinding: Binding<Float> {
        Binding {
            viewModel.selectedLight.intensity
        } set: { value in
            viewModel.updateSelectedLight { $0.intensity = value }
        }
    }

    private var selectedHeightBinding: Binding<Float> {
        Binding {
            viewModel.selectedLight.position.y
        } set: { value in
            viewModel.updateSelectedLight { $0.position.y = value }
        }
    }

    private var selectedXBinding: Binding<Float> {
        Binding {
            viewModel.selectedLight.position.x
        } set: { value in
            viewModel.updateSelectedLight { $0.position.x = value }
        }
    }

    private var selectedZBinding: Binding<Float> {
        Binding {
            viewModel.selectedLight.position.z
        } set: { value in
            viewModel.updateSelectedLight { $0.position.z = value }
        }
    }

    private var selectedBeamBinding: Binding<BeamSpreadPreset> {
        Binding {
            viewModel.selectedLight.beamSpread
        } set: { value in
            viewModel.updateSelectedLight {
                $0.beamSpread = value
                $0.beamOuterAngleDegrees = nil
            }
        }
    }

    private func pointSelectedLightAtObject() {
        viewModel.updateSelectedLight { light in
            let selectedObject = viewModel.selectedObject
            let target = selectedObject.position + SIMD3<Float>(
                0,
                SceneObjectEntityFactory.objectHeight(for: selectedObject) * selectedObject.scale / 2,
                0
            )
            let delta = target - light.position
            light.yawDegrees = atan2(delta.x, -delta.z).radiansToDegrees
            let horizontal = sqrt(delta.x * delta.x + delta.z * delta.z)
            light.pitchDegrees = atan2(delta.y, horizontal).radiansToDegrees
        }
    }
    
    private var selectedTextureBinding: Binding<MaterialTexture> {
        Binding {
            viewModel.selectedTexture
        } set: { texture in
            viewModel.selectTexture(texture)
        }
    }

}

private enum ControlTab: String, CaseIterable, Identifiable {
    case object
    case light
    case learn
    case scene

    var id: String { rawValue }

    var title: String {
        switch self {
        case .object: "Object"
        case .light: "Light"
        case .learn: "Learn"
        case .scene: "Scene"
        }
    }

    var symbol: String {
        switch self {
        case .object: "cube"
        case .light: "lightbulb"
        case .learn: "graduationcap"
        case .scene: "arkit"
        }
    }
}

private struct ShadowInformationPanel: View {
    let info: ShadowInfo

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
            row("Type", info.lightType)
            row("Intensity", String(format: "%.0f lm", info.intensity))
            row("Height", String(format: "%.2f m", info.lightHeight))
            row("Beam", info.beamSpread)
            row("Shadow Direction", info.shadowDirectionDegrees.map { String(format: "%.0f deg", $0) } ?? "Unavailable")
            row("Shadow Length", info.shadowLength.map { String(format: "%.2f m", $0) } ?? "Unavailable")
        }
        .font(.caption2)
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func row(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
        }
    }
}
