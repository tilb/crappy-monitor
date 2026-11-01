import AppKit
import SwiftUI

// LENS PROTOTYPE — throwaway.

/// Lets the window controller find the lens view (for its on-screen rect).
final class LensGeometry {
    weak var view: LensMTKView?
}

struct LensRootView: View {
    @ObservedObject var model: LensModel
    let capture: ScreenCapture
    let geometry: LensGeometry

    var body: some View {
        if model.mode == .wholeScreen {
            WholeScreenView(model: model)
        } else {
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
                    .accessibilityLabel("Lens: the screen under this window as \(model.name(model.previewID ?? model.activeID))")
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
        _ = LensRenderer(view: view, capture: capture, model: model)   // retained by the view
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
            Text("Whole Screen works without this permission.")
                .font(.caption)
                .foregroundStyle(.secondary)
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

// MARK: - Whole Screen controller

struct WholeScreenView: View {
    @ObservedObject var model: LensModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Image(systemName: "display")
                    .font(.system(size: 34))
                    .frame(width: 56)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your whole screen is degraded").font(.title3.weight(.semibold))
                    Text("Every app, including this window. Hold ⌥ to see the original.")
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Button { model.mode = .lens } label: {
                    HStack(spacing: 8) {
                        Text("Stop")
                        Text("⌃⌘W").foregroundStyle(.secondary)
                    }
                }
                .controlSize(.large)
            }
            .padding(20)
            .frame(maxHeight: .infinity)

            Divider()

            HStack(spacing: 12) {
                Picker("Monitor", selection: Binding(get: { model.activeID }, set: { model.use($0) })) {
                    ForEach(model.monitors) { Text($0.displayName).tag($0.id) }
                }
                .labelsHidden()
                .fixedSize()
                Picker("Age", selection: $model.age) {
                    ForEach(MonitorAge.allCases) { Text($0.label).tag($0) }
                }
                .fixedSize()
                if model.isEdited { Text("Edited").foregroundStyle(.secondary) }
                Spacer()
                AdjustButton(model: model, compact: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
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
                Text("\(model.age.phrase). Changes apply to this monitor only.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            FilterSliderView(label: "Brightness", range: LensParams.brightnessRange,
                             value: binding(\.brightness, \.brightness), format: "%.2f")
            FilterSliderView(label: "Contrast", range: LensParams.contrastRange,
                             value: binding(\.contrast, \.contrast), format: "%.2f")
            FilterSliderView(label: "Colour Temp (K)", range: LensParams.colorTempRange,
                             value: binding(\.colorTemp, \.colorTemp), format: "%.0f K")
            FilterSliderView(label: "Gamma", range: LensParams.gammaRange,
                             value: binding(\.gamma, \.gamma), format: "%.2f")
            FilterSliderView(label: "Black Level", range: LensParams.blackLevelRange,
                             value: binding(\.blackLevel, \.blackLevel), format: "%.3f")
            Toggle("Non-retina pixels", isOn: Binding(
                get: { model.activeParams.nonRetina },
                set: { model.overrides.nonRetina = $0 }))
                .disabled(model.mode == .wholeScreen)
                .help(model.mode == .wholeScreen
                      ? "In Whole Screen, use the control panel's display-mode switch"
                      : "Shows the lens at 1× with hard pixel edges")
            HStack {
                Spacer()
                Button("Reset") { model.overrides = LensOverrides() }
                    .disabled(!model.isEdited)
            }
        }
        .padding(16)
        .frame(width: 300)
    }

    private func binding(_ value: KeyPath<LensParams, Double>,
                         _ override: WritableKeyPath<LensOverrides, Double?>) -> Binding<Double> {
        Binding(get: { model.activeParams[keyPath: value] },
                set: { model.overrides[keyPath: override] = $0 })
    }
}
