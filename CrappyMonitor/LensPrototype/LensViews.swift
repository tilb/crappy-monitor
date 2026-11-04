import AppKit
import SwiftUI

/// Lets the window controller find the lens view (for its on-screen rect).
final class LensGeometry {
    weak var view: LensMTKView?
    var renderer: LensRenderer?   // shared by the lens and the thumbnails
}

struct LensRootView: View {
    @ObservedObject var model: LensModel
    let capture: ScreenCapture
    let geometry: LensGeometry

    var body: some View {
        VStack(spacing: 0) {
            LensArea(model: model, capture: capture, geometry: geometry)
            Divider()
            if model.stripVisible {
                StripView(model: model)
            } else {
                CollapsedFooter(model: model)
            }
        }
    }
}

// MARK: - Lens

struct LensArea: View {
    @ObservedObject var model: LensModel
    let capture: ScreenCapture
    let geometry: LensGeometry

    var body: some View {
        ZStack(alignment: .top) {
            switch model.captureState {
            case .needsPermission:
                PermissionView()
            case .failed(let message):
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle").font(.system(size: 32)).foregroundStyle(.secondary)
                    Text("The lens stopped").font(.title3.weight(.semibold))
                    Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Try Again") { model.retryCapture?() }
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .starting, .running:
                LensSurface(model: model, capture: capture, geometry: geometry)
                    .accessibilityLabel("Lens through \(model.name(model.previewID ?? model.activeID)), \(model.age.label)")
            }

            if model.captureState == .running {
                if model.showsOriginal {
                    LensCapsule {
                        Label("Showing original", systemImage: "option").fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 14)
                } else if let id = model.previewID {
                    LensCapsule {
                        HStack(spacing: 6) {
                            Text("Preview: \(model.name(id))").fontWeight(.semibold)
                            Text("Click to use ·").foregroundStyle(.secondary)
                            Image(systemName: "info.circle").foregroundStyle(.secondary)
                            Text("for details").foregroundStyle(.secondary)
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
        .animation(.easeOut(duration: 0.12), value: model.previewID)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LensSurface: NSViewRepresentable {
    let model: LensModel
    let capture: ScreenCapture
    let geometry: LensGeometry

    func makeNSView(context: Context) -> LensMTKView {
        let view = LensMTKView(frame: .zero)
        if let renderer = geometry.renderer {
            LensViewDriver(view: view, renderer: renderer, capture: capture, model: model)   // kept by the view
        }
        geometry.view = view
        return view
    }

    func updateNSView(_ view: LensMTKView, context: Context) {
        geometry.view = view
    }
}

struct LensCapsule<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .font(.callout)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.12)))
            .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
            .padding(.top, 14)
            .accessibilityElement(children: .combine)
    }
}

struct PermissionView: View {
    var body: some View {
        // The small D5 window has no room for the icon; drop it rather than cut the text.
        ViewThatFits(in: .vertical) {
            content(showIcon: true)
            content(showIcon: false)
            ScrollView { content(showIcon: false) }
        }
    }

    private func content(showIcon: Bool) -> some View {
        VStack(spacing: 14) {
            if showIcon {
                Image(systemName: "rectangle.dashed.badge.record")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
            }
            Text("Allow screen recording to use the lens")
                .font(.title3.weight(.semibold))
            Text("The lens shows whatever is underneath it. macOS only lets an app see the screen after you turn it on in System Settings › Privacy & Security › Screen Recording. Nothing is saved or sent anywhere.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 460)
            HStack(spacing: 12) {
                Button("Learn More") {
                    NSWorkspace.shared.open(URL(string: "https://support.apple.com/guide/mac-help/mchld6aa7d23/mac")!)
                }
                Button("Open System Settings…") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(showIcon ? 24 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - D5 collapsed footer

struct CollapsedFooter: View {
    @ObservedObject var model: LensModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(model.name(model.activeID))
                .fontWeight(.semibold)
                .lineLimit(1)
            if model.isEdited {
                Text("Edited").foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Menu("Change…") {
                ForEach(model.favourites, id: \.self) { id in
                    Button(model.name(id)) { model.use(id) }
                }
                Divider()
                Button("Show Strip") { model.stripVisible = true }
            }
            .fixedSize()
            AdjustButton(model: model, compact: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Adjust

struct AdjustButton: View {
    @ObservedObject var model: LensModel
    var compact = false

    var body: some View {
        Button { model.adjustShown.toggle() } label: {
            if compact {
                Image(systemName: "slider.horizontal.3").accessibilityLabel("Adjust")
            } else {
                Label("Adjust", systemImage: "slider.horizontal.3")
            }
        }
        .help("Adjust (⌥⌘A)")
        .popover(isPresented: $model.adjustShown, arrowEdge: .top) {
            AdjustView(model: model)
        }
    }
}

struct AdjustView: View {
    @ObservedObject var model: LensModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Adjust \(model.name(model.activeID))").font(.headline)
                Text("Changes apply to this monitor only.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            // Age here too, so it can be changed in the collapsed lens (design review 7.2A).
            Picker("Age", selection: $model.age) {
                ForEach(MonitorAge.allCases) { Text($0.label).tag($0) }
            }
            FilterSliderView(label: "Backlight", range: MonitorFilter.Edits.backlightRange,
                             value: edit(\.backlight, default: 1), format: "%.0f %%", scale: 100)
            FilterSliderView(label: "Panel contrast", range: MonitorFilter.Edits.contrastRange,
                             value: edit(\.contrastRatio, default: model.active?.contrastRatio ?? 1000),
                             format: "%.0f:1")
            FilterSliderView(label: "White point", range: MonitorFilter.Edits.colorTemperatureRange,
                             value: edit(\.colorTemperature, default: model.activeFilter?.whiteTemperature ?? 6500),
                             format: "%.0f K")
            FilterSliderView(label: "Gamma", range: MonitorFilter.Edits.gammaRange,
                             value: edit(\.gamma, default: MonitorFilter.Constants.panelGamma), format: "%.2f")
            FilterSliderView(label: "Office light", range: MonitorFilter.Edits.officeLightRange,
                             value: edit(\.officeLight, default: 1), format: "%.1f×")
            Toggle("Non-retina pixels", isOn: Binding(
                get: { model.activeFilter?.nonRetina ?? true },
                set: { model.edits.nonRetina = $0 }))
                .help("Shows the lens at the monitor's own pixel size")
            HStack {
                Spacer()
                Button("Reset") { model.edits = MonitorFilter.Edits() }
                    .disabled(!model.isEdited)
            }
        }
        .padding(16)
        .frame(width: 300)
    }

    private func edit(_ key: WritableKeyPath<MonitorFilter.Edits, Double?>, default value: Double) -> Binding<Double> {
        Binding(get: { model.edits[keyPath: key] ?? value },
                set: { model.edits[keyPath: key] = $0 })
    }
}
