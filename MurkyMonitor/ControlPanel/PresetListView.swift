import SwiftUI

private struct PresetRowView: View {
    let preset: DegradationPreset
    @EnvironmentObject var settings: FilterSettings

    var body: some View {
        let isActive = settings.activePresetID == preset.id
        Button {
            preset.apply(to: settings)
        } label: {
            HStack {
                Text(preset.name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isActive {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .fontWeight(.semibold)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isActive
                    ? AnyShapeStyle(Color.accentColor.opacity(0.12))
                    : AnyShapeStyle(Color.primary.opacity(0.06)),
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
    }
}

struct PresetListView: View {
    @EnvironmentObject var presetsStore: PresetsStore
    @EnvironmentObject var settings: FilterSettings

    var body: some View {
        ScrollView {
            if presetsStore.presets.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No presets loaded")
                        .font(.headline)
                    Text("Check that Presets.json is included in the app bundle.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                VStack(spacing: 8) {
                    ForEach(presetsStore.presets) { (preset: DegradationPreset) in
                        PresetRowView(preset: preset)
                            .environmentObject(settings)
                    }
                }
                .padding()
            }
        }
    }
}
