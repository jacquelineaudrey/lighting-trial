import SwiftUI

private enum ControlTab: String, CaseIterable, Identifiable {
    case object = "Object"
    case light = "Light"
    case texture = "Texture"
    case learn = "Learn"

    var id: String { rawValue }
}

struct ContentView: View {
    @StateObject private var viewModel = ARSceneViewModel()

    var body: some View {
        ZStack {
            ARViewContainer(viewModel: viewModel)
                .ignoresSafeArea()

            VStack {
                StatusBanner(text: viewModel.surfaceGuidanceText)
                    .padding(.top, 12)

                Spacer()

                SceneControlPanel(viewModel: viewModel)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
        }
        .sheet(item: $viewModel.selectedConcept) { concept in
            ShadowConceptExplanationView(concept: concept)
                .presentationDetents([.height(180)])
        }
    }
}

private struct StatusBanner: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout.weight(.semibold))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.thinMaterial, in: Capsule())
            .accessibilityLabel(text)
    }
}

private struct ShadowConceptExplanationView: View {
    let concept: ShadowConcept

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(concept.rawValue)
                .font(.headline)
            Text(concept.explanation)
                .font(.body)
            Spacer()
        }
    }

    // MARK: - Light tab (add / delete lives here)

    private var lightTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Lights (\(viewModel.lights.count)/\(ARSceneViewModel.maximumLights))")
                        .font(.footnote.weight(.semibold))
                    Spacer()
                    Button {
                        viewModel.addLight()
                    } label: {
                        Label("Add Light", systemImage: "plus.circle.fill")
                    }
                    .disabled(viewModel.lights.count >= ARSceneViewModel.maximumLights)

                    Button(role: .destructive) {
                        viewModel.deleteSelectedLight()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(viewModel.lights.count <= 1)
                }
                .font(.footnote)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.lights) { light in
                            Button(light.name) { viewModel.selectLight(id: light.id) }
                                .buttonStyle(.bordered)
                                .tint(light.id == viewModel.selectedLightID ? .cyan : .gray)
                        }
                    }
                }

                Picker("Type", selection: Binding(
                    get: { viewModel.selectedLight.type },
                    set: { newValue in viewModel.updateSelectedLight { $0.type = newValue } }
                )) {
                    ForEach(LearningLightType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                ColorPicker("Color", selection: Binding(
                    get: { viewModel.selectedLight.color },
                    set: { newValue in viewModel.updateSelectedLight { $0.color = newValue } }
                ))
                .font(.footnote)

                VStack(alignment: .leading) {
                    Text("Intensity: \(Int(viewModel.selectedLight.intensity))").font(.caption)
                    Slider(value: Binding(
                        get: { viewModel.selectedLight.intensity },
                        set: { newValue in viewModel.updateSelectedLight { $0.intensity = newValue } }
                    ), in: 100...6000)
                }

                VStack(alignment: .leading) {
                    Text("Height: \(String(format: "%.2f", viewModel.selectedLight.position.y))m").font(.caption)
                    Slider(value: Binding(
                        get: { viewModel.selectedLight.position.y },
                        set: { newValue in viewModel.updateSelectedLight { $0.position.y = newValue } }
                    ), in: -0.2...2.0)
                }

                VStack(alignment: .leading) {
                    Text("X position: \(String(format: "%.2f", viewModel.selectedLight.position.x))m").font(.caption)
                    Slider(value: Binding(
                        get: { viewModel.selectedLight.position.x },
                        set: { newValue in viewModel.updateSelectedLight { $0.position.x = newValue } }
                    ), in: -0.9...0.9)
                }

                VStack(alignment: .leading) {
                    Text("Z position: \(String(format: "%.2f", viewModel.selectedLight.position.z))m").font(.caption)
                    Slider(value: Binding(
                        get: { viewModel.selectedLight.position.z },
                        set: { newValue in viewModel.updateSelectedLight { $0.position.z = newValue } }
                    ), in: -0.9...0.9)
                }

                Picker("Beam", selection: Binding(
                    get: { viewModel.selectedLight.beamSpread },
                    set: { newValue in viewModel.updateSelectedLight { $0.beamSpread = newValue } }
                )) {
                    ForEach(BeamSpreadPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    // MARK: - Texture tab (new feature)

    private var textureTab: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: isRegularWidth ? 110 : 84))], spacing: 10) {
                ForEach(MaterialTexture.library) { texture in
                    Button {
                        viewModel.selectTexture(texture)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: texture.previewSystemImage)
                                .font(.title2)
                            Text(texture.name).font(.caption)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(
                            texture.id == viewModel.selectedTexture.id ? Color.cyan.opacity(0.3) : Color.gray.opacity(0.15),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Learn tab

    private var learnTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Light direction", isOn: $viewModel.showLightDirection)
                Toggle("Representative rays", isOn: $viewModel.showLightRays)
                Toggle("Projection lines", isOn: $viewModel.showProjectionLines)
                Toggle("Ground shadow direction", isOn: $viewModel.showGroundProjection)
                Toggle("Shadow labels", isOn: $viewModel.showShadowLabels)

                if viewModel.isObjectPlaced {
                    Divider()
                    shadowCalculationPanel
                }

                if let concept = viewModel.selectedConcept {
                    Divider()
                    Text(concept.rawValue).font(.headline)
                    Text(concept.explanation).font(.footnote)
                }
            }
            .font(.footnote)
        }
    }

    private var shadowCalculationPanel: some View {
        let info = viewModel.shadowInfo

        return VStack(alignment: .leading, spacing: 5) {
            Text("Live Shadow Calculation")
                .font(.headline)

            calculationRow("Light", "\(info.lightType) · \(Int(info.intensity))")
            calculationRow("Height", String(format: "%.2f m", info.lightHeight))
            calculationRow(
                "Direction",
                info.shadowDirectionDegrees.map { String(format: "%.0f°", $0) } ?? "Directly below"
            )
            calculationRow(
                "Shadow length",
                info.shadowLength.map { String(format: "%.2f m", $0) } ?? "Not available"
            )
        }
        .padding(10)
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
    }

    private func calculationRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
        .font(.footnote)
    }
}

#Preview("iPhone") {
    ContentView()
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
