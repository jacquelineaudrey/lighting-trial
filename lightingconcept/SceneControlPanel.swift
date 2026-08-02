import SwiftUI

struct SceneControlPanel: View {
    @ObservedObject var viewModel: ARSceneViewModel
    var isInspector = false
    @State private var selectedTab = ControlTab.object

    var body: some View {
        VStack(spacing: 10) {
            Picker("Controls", selection: $selectedTab) {
                ForEach(ControlTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.symbol).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            ScrollView {
                Group {
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
            .scrollIndicators(.hidden)
            .frame(maxHeight: isInspector ? .infinity : 330)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
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
                            Text("\(object.name) — \(object.type.rawValue)")
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
                            Text(viewModel.selectedObject.type.rawValue)
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
                    "\(viewModel.selectedObject.name), \(viewModel.selectedObject.type.rawValue), \(viewModel.objects.count) objects"
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

            ObjectShapePreviewPicker(selection: $viewModel.selectedObjectType)

            Picker("Mode", selection: $viewModel.interactionMode) {
                ForEach(InteractionMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            sliderRow("Object Size", value: $viewModel.objectScale, range: 0.35...1.6, step: 0.05, suffix: "x")

            if viewModel.selectedObjectType.supportsYawRotation {
                sliderRow("Object Rotation", value: $viewModel.objectYawDegrees, range: -180...180, step: 1, suffix: "deg")
            }

            Button {
                viewModel.resetObjectPosition()
            } label: {
                Label("Reset Object", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
        }
    }

    private var lightControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Picker("Selected Light", selection: $viewModel.selectedLightID) {
                    ForEach(viewModel.lights) { light in
                        Text(light.name).tag(light.id)
                    }
                }
                Button("Add Light", systemImage: "plus", action: viewModel.addLight)
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
                .disabled(viewModel.lights.count >= 3)

                Button("Remove Light", systemImage: "minus", action: viewModel.removeSelectedLight)
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
                .disabled(viewModel.lights.count <= 1)
            }

            Picker("Light Type", selection: selectedLightTypeBinding) {
                ForEach(LearningLightType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)

            ColorPicker("Colour", selection: selectedLightColorBinding, supportsOpacity: false)

            sliderRow("Intensity", value: selectedIntensityBinding, range: 100...6000, step: 50, suffix: "lm")
            sliderRow("Height", value: selectedHeightBinding, range: 0.12...0.9, step: 0.01, suffix: "m")
            sliderRow("X Position", value: selectedXBinding, range: -0.7...0.7, step: 0.01, suffix: "m")
            sliderRow("Z Position", value: selectedZBinding, range: -0.7...0.7, step: 0.01, suffix: "m")

            if viewModel.selectedLight.type == .spot {
                sliderRow("Yaw", value: selectedYawBinding, range: -180...180, step: 1, suffix: "deg")
                sliderRow("Pitch", value: selectedPitchBinding, range: -85...10, step: 1, suffix: "deg")
                Picker("Beam Spread", selection: selectedBeamBinding) {
                    ForEach(BeamSpreadPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    pointSelectedLightAtObject()
                } label: {
                    Label("Point at Object", systemImage: "scope")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var learnControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Show Light Direction", isOn: $viewModel.showLightDirection)
            Toggle("Show Light Rays", isOn: $viewModel.showLightRays)
            Toggle("Show Projection Lines", isOn: $viewModel.showProjectionLines)
            Toggle("Show Ground Projection", isOn: $viewModel.showGroundProjection)
            Toggle("Show Shadow Labels", isOn: $viewModel.showShadowLabels)
            Toggle("Show Shadow Information", isOn: $viewModel.showShadowInformation)

            if viewModel.showShadowInformation {
                ShadowInformationPanel(info: viewModel.shadowInfo)
            }
        }
    }

    private var sceneControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                viewModel.resetScene()
            } label: {
                Label("Reset Scene", systemImage: "trash")
            }
            .buttonStyle(.bordered)

            Button {
                viewModel.rescanSurface()
            } label: {
                Label("Re-scan Surface", systemImage: "viewfinder")
            }
            .buttonStyle(.borderedProminent)

            Text("On LiDAR devices, RealityKit uses scene-understanding geometry for real-world lighting interaction. Other devices use a faint flat receiver fallback.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func sliderRow(_ title: String, value: Binding<Float>, range: ClosedRange<Float>, step: Float, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue, specifier: "%.1f") \(suffix)")
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
        }
        .font(.caption)
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

    private var selectedYawBinding: Binding<Float> {
        Binding {
            viewModel.selectedLight.yawDegrees
        } set: { value in
            viewModel.updateSelectedLight { $0.yawDegrees = value }
        }
    }

    private var selectedPitchBinding: Binding<Float> {
        Binding {
            viewModel.selectedLight.pitchDegrees
        } set: { value in
            viewModel.updateSelectedLight { $0.pitchDegrees = value }
        }
    }

    private var selectedBeamBinding: Binding<BeamSpreadPreset> {
        Binding {
            viewModel.selectedLight.beamSpread
        } set: { value in
            viewModel.updateSelectedLight { $0.beamSpread = value }
        }
    }

    private func pointSelectedLightAtObject() {
        viewModel.updateSelectedLight { light in
            let selectedObject = viewModel.selectedObject
            let target = selectedObject.position + SIMD3<Float>(
                0,
                ObjectFactory.objectHeight(for: selectedObject.type) * selectedObject.scale / 2,
                0
            )
            let delta = target - light.position
            light.yawDegrees = atan2(delta.x, -delta.z).radiansToDegrees
            let horizontal = sqrt(delta.x * delta.x + delta.z * delta.z)
            light.pitchDegrees = atan2(delta.y, horizontal).radiansToDegrees
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
            row("Yaw", String(format: "%.0f deg", info.yawDegrees))
            row("Pitch", String(format: "%.0f deg", info.pitchDegrees))
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
