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
        Group {
            switch model.captureState {
            case .welcome:
                WelcomeView(model: model, renderer: geometry.renderer)
            case .needsPermission:
                PermissionStepsView()
            case .needsRelaunch:
                RelaunchView(model: model)
            default:
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
        .animation(.easeInOut(duration: 0.3), value: model.isOnboarding)
    }
}

// MARK: - Lens

struct LensArea: View {
    @ObservedObject var model: LensModel
    let capture: ScreenCapture
    let geometry: LensGeometry
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            switch model.captureState {
            case .welcome, .needsPermission, .needsRelaunch:
                EmptyView()   // shown full-window by LensRootView
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

            if (model.captureState == .starting || model.captureState == .running) && !model.lensHasFrame {
                LoadingCapsule()
            } else if model.captureState == .running {
                if model.showsOriginal {
                    LensCapsule(announcement: "Showing original") {
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
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: model.previewID)
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
    /// Spoken by VoiceOver when the capsule appears (PRD §5.4, 6.3A).
    var announcement: String? = nil
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
            .onAppear { if let announcement { Accessibility.announce(announcement) } }
    }
}

/// "Starting the lens…", only when the first frame takes longer than 0.5 s (PRD §5.1, 2.2).
struct LoadingCapsule: View {
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Always in the hierarchy (an empty view never appears, so its task would never
        // run); invisible until the first frame is late.
        LensCapsule {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Starting the lens…").fontWeight(.semibold)
            }
        }
        .opacity(shown ? 1 : 0)
        .accessibilityHidden(!shown)
        .task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { shown = true }
            Accessibility.announce("Starting the lens")
        }
    }
}

enum Accessibility {
    /// Asks VoiceOver to speak `text` now.
    static func announce(_ text: String) {
        guard let element = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        NSAccessibility.post(element: element, notification: .announcementRequested,
                             userInfo: [.announcement: text,
                                        .priority: NSAccessibilityPriorityLevel.high.rawValue])
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
