import AppKit
import SwiftUI

// MARK: - D1 strip

struct StripView: View {
    @ObservedObject var model: LensModel

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                header("Last used")
                TileView(model: model, id: model.activeID, slot: .lastUsed)
            }
            .padding(.leading, 16)
            .padding(.trailing, 12)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    header(model.query.isEmpty ? "Favourites" : "Matches in favourites")
                    Spacer(minLength: 12)
                    Text("All monitors are based on their specifications")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 6) {
                        ForEach(model.stripFavourites, id: \.self) { id in
                            TileView(model: model, id: id, slot: .favourite)
                        }
                        MoreTile { model.openBrowseAll() }
                    }
                }
            }
            .padding(.horizontal, 12)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                header("Age")
                Picker("Age", selection: $model.age) {
                    ForEach(MonitorAge.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden()
                .frame(width: 150)
                .help("Adds wear to whichever monitor you look through")
                AdjustButton(model: model)
            }
            .padding(.horizontal, 16)
            .frame(width: 190, alignment: .leading)
        }
        .padding(.vertical, 12)
        .frame(height: 170)
        .background(Color(nsColor: .windowBackgroundColor))
        .onHover { inside in if !inside { model.leftStrip() } }
    }

    private func header(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}

struct TileView: View {
    enum Slot { case lastUsed, favourite }

    @ObservedObject var model: LensModel
    let id: String
    let slot: Slot
    @State private var hovering = false

    private var key: String { (slot == .lastUsed ? "last:" : "fav:") + id }
    private var isActive: Bool { id == model.activeID }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack(alignment: .topTrailing) {
                thumbnail
                    .frame(width: Thumbnailer.tileSize.width, height: Thumbnailer.tileSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(isActive ? Color.accentColor : Color.primary.opacity(0.15),
                                          lineWidth: isActive ? 2.5 : 1)
                    )
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.accentColor)
                        .padding(5)
                        .accessibilityHidden(true)
                } else if hovering {
                    Button { model.infoKey = key } label: {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 17))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.black.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .padding(5)
                    .help("Show Info (⌘I)")
                }
            }
            Text(model.name(id))
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
            if isActive {
                Text("Active")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tint)
            }
        }
        .padding(4)
        .frame(width: 132, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(hovering ? Color.primary.opacity(0.07) : .clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { model.use(id) }
        .onHover { inside in
            hovering = inside
            if inside { model.hoverBegan(id, key: key) } else { model.hoverEnded(key: key) }
        }
        .contextMenu { menu }
        .popover(isPresented: Binding(get: { model.infoKey == key },
                                      set: { if !$0, model.infoKey == key { model.infoKey = nil } }),
                 arrowEdge: .top) {
            MonitorInfoView(model: model, id: id)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { model.use(id) }
        .accessibilityAction(named: "Show Info") { model.infoKey = key }
    }

    @ViewBuilder private var thumbnail: some View {
        if let image = model.thumbnails[id] {
            Image(nsImage: image).resizable().interpolation(.none)
        } else {
            Rectangle().fill(Color.secondary.opacity(0.2))
        }
    }

    @ViewBuilder private var menu: some View {
        Button("Use") { model.use(id) }
        Button("Show Info") { model.infoKey = key }
        Divider()
        if model.isFavourite(id) {
            Button("Move Left") { model.move(id, by: -1) }
                .disabled(model.favourites.first == id)
            Button("Move Right") { model.move(id, by: 1) }
                .disabled(model.favourites.last == id)
            Button("Remove from Favourites") { model.removeFavourite(id) }
        } else {
            Button("Add to Favourites") { model.addFavourite(id) }
        }
    }

    private var accessibilityText: String {
        var parts = [model.name(id)]
        if isActive { parts.append("active") }
        if slot == .favourite, let i = model.favourites.firstIndex(of: id) { parts.append("favourite \(i + 1)") }
        return parts.joined(separator: ", ")
    }
}

struct MoreTile: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: "plus").font(.system(size: 16))
                Text("More…").font(.system(size: 12))
            }
            .frame(width: 100, height: Thumbnailer.tileSize.height)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(.secondary)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(4)
        .help("All monitors")
        .accessibilityLabel("More monitors")
    }
}

// MARK: - D4 info popover

struct MonitorInfoView: View {
    @ObservedObject var model: LensModel
    let id: String

    var body: some View {
        let p = model.monitor(id)
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.name(id)).font(.title3.weight(.semibold))
                Text("\(model.age.phrase) · change the age in the strip").foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 5) {
                row("Panel type", p.map {
                    "\($0.panelType.rawValue), \($0.isEstimated("backlight") ? "≈ " : "")\($0.backlight.rawValue) backlight"
                })
                row("Resolution", p.map { "\($0.resolution[0]) × \($0.resolution[1])" })
                row("Size", p.map { String(format: "%.1f″ · %.0f ppi", $0.sizeInches, $0.pixelsPerInch) })
                row("Contrast", p.map { String(format: "%.0f:1", $0.contrastRatio) })
                row("Brightness", p.map { String(format: "%.0f cd/m²", $0.maxBrightness) })
                row("Colour range", p?.gamutSpec)
                row("sRGB coverage", p.map { String(format: "%.0f %% (from EDID)", $0.sRGBCoverage * 100) })
                row("Released", p?.released.map(String.init), estimated: p?.isEstimated("released") ?? false)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.1)))

            if p.map({ !$0.estimated.isEmpty }) ?? false {
                Text("≈ estimated from the datasheet or similar models")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Label {
                Text("**Based on specifications.** Built from the datasheet and the monitor’s own display data (EDID). The age you pick adds wear on top; brightness loss is shown as-is, though people using this monitor get used to it. Real monitors also vary with their settings and the light in the room.")
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "info.circle")
            }

            HStack {
                Link("Looks wrong? Report it", destination: model.reportURL(for: id))
                Spacer()
                if model.isFavourite(id) {
                    Button("Remove from Favourites") {
                        model.infoKey = nil
                        model.removeFavourite(id)
                    }
                } else {
                    Button("Add to Favourites") { model.addFavourite(id) }
                }
            }
        }
        .padding(18)
        .frame(width: 360)
    }

    /// "—" for a missing value (VoiceOver: "Unknown"), "≈" before an estimated one (design 2.3A).
    private func row(_ label: String, _ value: String?, estimated: Bool = false) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            if let value {
                Text(estimated ? "≈ \(value)" : value)
                    .accessibilityLabel(estimated ? "about \(value)" : value)
            } else {
                Text("—").accessibilityLabel("Unknown")
            }
        }
    }
}

// MARK: - D3 search results

struct SearchResultsView: View {
    @ObservedObject var model: LensModel

    var body: some View {
        let results = model.searchResults()
        let flat = results.flat
        VStack(alignment: .leading, spacing: 2) {
            if !results.favourites.isEmpty {
                section("In your favourites")
                ForEach(results.favourites) { p in
                    row(p, index: flat.firstIndex(of: p.id) ?? 0, favourite: true)
                }
            }
            if !results.others.isEmpty {
                section("Not in favourites yet")
                ForEach(results.others) { p in
                    row(p, index: flat.firstIndex(of: p.id) ?? 0, favourite: false)
                }
            }
            if flat.isEmpty {
                Text("No monitors match “\(model.searchText)”")
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
            Divider().padding(.vertical, 4)
            if results.hiddenCount > 0 {
                Button("Show all \(flat.count + results.hiddenCount) results") { model.showAllResults = true }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8).padding(.vertical, 3)
            }
            Button("Not listed? Request it on GitHub…") {
                NSWorkspace.shared.open(model.requestURL())
                model.clearSearch()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8).padding(.vertical, 3)
        }
        .padding(8)
        .frame(width: 320, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func section(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 2)
            .accessibilityAddTraits(.isHeader)
    }

    private func row(_ p: MonitorProfile, index: Int, favourite: Bool) -> some View {
        let selected = index == model.searchSelection
        return HStack {
            highlighted(p.displayName)
            Spacer()
            if !favourite {
                Button("Add") { model.addFavourite(p.id) }
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .foregroundStyle(selected ? Color.white : Color.primary)
        .background(RoundedRectangle(cornerRadius: 5).fill(selected ? Color.accentColor : .clear))
        .contentShape(Rectangle())
        .onTapGesture {
            model.use(p.id)
            model.clearSearch()
        }
        .onHover { if $0 { model.searchSelection = index } }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func highlighted(_ name: String) -> Text {
        let q = model.query
        guard !q.isEmpty, let r = name.range(of: q, options: .caseInsensitive) else { return Text(name) }
        return Text(name[..<r.lowerBound]) + Text(name[r]).fontWeight(.bold) + Text(name[r.upperBound...])
    }
}
