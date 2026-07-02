import SwiftUI

// Pure functions — unit-testable without SwiftUI.
func shouldShowDpiBanner(
    activePresetID: String?,
    presets: [DegradationPreset],
    pixelSimulation: Bool,
    lowResModeAvailable: Bool
) -> Bool {
    guard lowResModeAvailable,
          !pixelSimulation,
          let id = activePresetID,
          let preset = presets.first(where: { $0.id == id })
    else { return false }
    return preset.simulateLowDpi
}

func shouldShowReversePixelBanner(
    activePresetID: String?,
    presets: [DegradationPreset],
    pixelSimulation: Bool
) -> Bool {
    guard pixelSimulation,
          let id = activePresetID,
          let preset = presets.first(where: { $0.id == id })
    else { return pixelSimulation }
    return !preset.simulateLowDpi
}

struct ControlPanelView: View {
    @EnvironmentObject var settings: FilterSettings
    @EnvironmentObject var presetsStore: PresetsStore
    @State private var selectedTab = 1

    private var showDpiBanner: Bool {
        shouldShowDpiBanner(
            activePresetID: settings.activePresetID,
            presets: presetsStore.presets,
            pixelSimulation: settings.pixelSimulation,
            lowResModeAvailable: settings.lowResModeAvailable
        )
    }

    private var showReversePixelBanner: Bool {
        shouldShowReversePixelBanner(
            activePresetID: settings.activePresetID,
            presets: presetsStore.presets,
            pixelSimulation: settings.pixelSimulation
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // A/B compare banner — shown while ⌥ is held.
            if settings.isABActive {
                bannerView(
                    icon: "eye",
                    text: "Comparing — release ⌥ to restore simulation",
                    color: .accentColor
                )
            }

            // DPI opt-in banner — shown when the active preset recommends low-DPI simulation.
            if showDpiBanner {
                HStack(spacing: 8) {
                    Image(systemName: "display")
                        .imageScale(.small)
                    Text("This monitor was \(currentPresetDpi) DPI. Enable non-retina simulation?")
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Toggle("", isOn: $settings.pixelSimulation)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .controlSize(.mini)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.12))
                .foregroundStyle(Color.orange)
            }

            // Reverse banner — shown when pixel simulation is on for a preset that doesn't call for it.
            if showReversePixelBanner {
                HStack(spacing: 8) {
                    Image(systemName: "display.trianglebadge.exclamationmark")
                        .imageScale(.small)
                    Text("Non-retina simulation is active — disable?")
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Toggle("", isOn: $settings.pixelSimulation)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .controlSize(.mini)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.1))
                .foregroundStyle(.secondary)
            }

            // Header
            HStack {
                Text("Crappy Monitor")
                    .font(.headline)
                Spacer()
                Toggle("Enabled", isOn: $settings.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding()

            Divider()

            Picker("", selection: $selectedTab) {
                Text("Presets").tag(1)
                Text("Filters").tag(0)
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])

            if selectedTab == 0 {
                FiltersTabView()
                    .environmentObject(settings)
            } else {
                PresetListView()
                    .environmentObject(presetsStore)
                    .environmentObject(settings)
            }

            Spacer()
        }
        .frame(width: 320, height: 480)
    }

    private var currentPresetDpi: String {
        guard let id = settings.activePresetID,
              let preset = presetsStore.presets.first(where: { $0.id == id }),
              let dpi = preset.dpi
        else { return "low" }
        return "\(dpi)"
    }

    @ViewBuilder
    private func bannerView(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
                .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
    }
}

struct FiltersTabView: View {
    @EnvironmentObject var settings: FilterSettings

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                GroupBox("Brightness & Colour") {
                    FilterSliderView(label: "Brightness",
                                     range: -1.0...0.0,
                                     value: $settings.brightness,
                                     format: "%.2f")
                    FilterSliderView(label: "Contrast",
                                     range: 0.5...1.5,
                                     value: $settings.contrast,
                                     format: "%.2f")
                    FilterSliderView(label: "Colour Temp (K)",
                                     range: 3000...9000,
                                     value: $settings.colorTempShift,
                                     format: "%.0f K")
                }

                GroupBox("Panel Aging") {
                    FilterSliderView(label: "Gamma Exponent",
                                     range: 0.8...1.4,
                                     value: $settings.gammaExponent,
                                     format: "%.2f")
                    FilterSliderView(label: "Black Level",
                                     range: 0.0...0.15,
                                     value: $settings.blackLevel,
                                     format: "%.3f")
                    Toggle("Non-retina pixels", isOn: $settings.pixelSimulation)
                        .disabled(!settings.lowResModeAvailable)
                        .help(settings.lowResModeAvailable
                              ? "Simulates lower pixel density by switching display mode"
                              : "Not available — requires a Retina display or a monitor with a low-resolution mode")
                }

                Button("Reset to Defaults") {
                    withAnimation {
                        settings.brightness = 0.0
                        settings.contrast = 1.0
                        settings.colorTempShift = 6500
                        settings.gammaExponent = 1.0
                        settings.blackLevel = 0.0
                        settings.pixelSimulation = false
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
    }
}
