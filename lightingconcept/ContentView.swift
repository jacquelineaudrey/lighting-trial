//
//  ContentView.swift
//  lightingconcept
//
//  Responsive for iPhone and iPad (including iPad Pro 11"): compact-width
//  devices get a floating bottom sheet, regular-width devices (iPad,
//  iPhone Plus/Max landscape) get a fixed-width side panel so the AR camera
//  view isn't mostly covered by controls.
//

import Foundation
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
    @State private var selectedTab: ControlTab = .object
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Regular width = iPad (any orientation/multitasking size above ~half
    /// split view) and iPhone Plus/Max in landscape. Compact = iPhone
    /// portrait and iPad narrow split view.
    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    var body: some View {
        Group {
            if isRegularWidth {
                regularWidthLayout
            } else {
                compactWidthLayout
            }
        }
    }

    // MARK: - Regular width (iPad): side panel, AR view fills the rest

    private var regularWidthLayout: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .top) {
                ARContainerView(viewModel: viewModel)
                statusBar
                    .padding(.top, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            VStack(spacing: 0) {
                if let warning = viewModel.collisionWarning {
                    collisionBanner(text: warning)
                        .padding(.top, 12)
                }
                controlPanelContent
                    .padding(16)
            }
            .frame(width: 380)
            .frame(maxHeight: .infinity)
            .background(.regularMaterial)
        }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Compact width (iPhone): floating bottom sheet over the AR view

    private var compactWidthLayout: some View {
        ZStack(alignment: .bottom) {
            ARContainerView(viewModel: viewModel)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                statusBar
                    .padding(.top, 12)
                Spacer()
                if let warning = viewModel.collisionWarning {
                    collisionBanner(text: warning)
                }
                controlPanelContent
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 12)
                    .frame(maxHeight: 320)
            }
            .padding(.bottom, 8)
        }
    }

    // MARK: - Shared chrome

    private var statusBar: some View {
        Text(statusText)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
    }

    private var statusText: String {
        switch viewModel.surfaceState {
        case .scanning: "Move the device to find a surface"
        case .found: "Tap the surface to place an object"
        case .placed: "\(viewModel.selectedObjectType.rawValue) placed"
        }
    }

    private func collisionBanner(text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.red.opacity(0.85), in: Capsule())
            .padding(.bottom, 8)
            .transition(.opacity)
    }

    /// Tab picker + the currently selected tab's body. Reused by both
    /// layouts, just placed inside a different container.
    private var controlPanelContent: some View {
        VStack(spacing: 12) {
            Picker("Tab", selection: $selectedTab) {
                ForEach(ControlTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            Group {
                switch selectedTab {
                case .object: objectTab
                case .light: lightTab
                case .texture: textureTab
                case .learn: learnTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    // MARK: - Object tab

    private var objectTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Object", selection: $viewModel.selectedObjectType) {
                    ForEach(LearningObjectType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Mode", selection: $viewModel.interactionMode) {
                    ForEach(InteractionMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if isRegularWidth {
                    VStack(alignment: .leading, spacing: 8) {
                        Button("Reset Object") { viewModel.pendingResetObject.toggle() }
                        Button("Reset Scene") { viewModel.pendingResetScene.toggle() }
                        Button("Rescan Surface") { viewModel.pendingRescanSurface.toggle() }
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack {
                        Button("Reset Object") { viewModel.pendingResetObject.toggle() }
                        Button("Reset Scene") { viewModel.pendingResetScene.toggle() }
                        Button("Rescan Surface") { viewModel.pendingRescanSurface.toggle() }
                    }
                    .buttonStyle(.bordered)
                    .font(.footnote)
                }
            }
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
                    ), in: 100...2000)
                }

                VStack(alignment: .leading) {
                    Text("Height: \(String(format: "%.2f", viewModel.selectedLight.position.y))m").font(.caption)
                    Slider(value: Binding(
                        get: { viewModel.selectedLight.position.y },
                        set: { newValue in viewModel.updateSelectedLight { $0.position.y = newValue } }
                    ), in: 0.1...1.0)
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

#Preview("iPad Pro 11-inch") {
    ContentView()
        .previewDevice("iPad Pro (11-inch) (4th generation)")
}
