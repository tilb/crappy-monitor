import SwiftUI

private struct PresetRowView: View {
    let preset: DegradationPreset
    @EnvironmentObject var settings: FilterSettings
    @EnvironmentObject var presetsStore: PresetsStore

    var body: some View {
        let isActive = settings.activePresetID == preset.id
        Button {
            preset.apply(to: settings)
        } label: {
            HStack(spacing: 10) {
                thumbnailView
                    .frame(width: 56, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                        .font(.body)
                        .fontWeight(isActive ? .semibold : .regular)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)

                    if let sub = preset.specSubtitle {
                        Text(sub)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if isActive {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .fontWeight(.semibold)
                        .imageScale(.small)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                isActive
                    ? AnyShapeStyle(Color.accentColor.opacity(0.12))
                    : AnyShapeStyle(Color.primary.opacity(0.05)),
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let img = presetsStore.thumbnails[preset.id] {
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.25))
        }
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
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                    ForEach(presetsStore.groupedByDecade) { group in
                        Section {
                            VStack(spacing: 6) {
                                ForEach(group.presets) { preset in
                                    PresetRowView(preset: preset)
                                        .environmentObject(settings)
                                        .environmentObject(presetsStore)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        } header: {
                            Text(group.id)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                                .padding(.top, 10)
                                .padding(.bottom, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.background)
                        }
                    }
                }
            }
        }
    }
}
