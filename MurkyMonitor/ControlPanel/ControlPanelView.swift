import SwiftUI

struct ControlPanelView: View {
    @EnvironmentObject var settings: FilterSettings
    @EnvironmentObject var presetsStore: PresetsStore
    // Default to Presets tab — it's the product; Filters are secondary refinement.
    @State private var selectedTab = 1

    var body: some View {
        VStack(spacing: 0) {
            // A/B compare banner — shown while ⌥ is held.
            if settings.isABActive {
                HStack(spacing: 6) {
                    Image(systemName: "eye")
                    Text("Comparing — release ⌥ to restore simulation")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.15))
                .foregroundStyle(Color.accentColor)
            }

            // Header
            HStack {
                Text("MurkyMonitor")
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
