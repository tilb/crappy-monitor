import AppKit
import Metal
import SwiftUI

// MARK: - Demo images

/// The sample screen, once as the Mac shows it and once per age through a monitor,
/// rendered by the real `LensRenderer`: the intro shows exactly what the lens will do.
@MainActor
final class DemoImages: ObservableObject {
    @Published private(set) var original: NSImage?
    @Published private(set) var aged: [MonitorAge: NSImage] = [:]

    func make(renderer: LensRenderer?, profile: MonitorProfile?) {
        guard original == nil else { return }
        let r = ImageRenderer(content: SampleScreen())
        r.scale = 2
        guard let cg = r.cgImage, let bytes = Self.bgra(cg) else { return }
        let w = cg.width, h = cg.height
        original = NSImage(cgImage: cg, size: SampleScreen.size)

        guard let renderer, let profile else { return }
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
        td.usage = .shaderRead
        td.storageMode = .managed
        guard let texture = renderer.device.makeTexture(descriptor: td) else { return }
        bytes.withUnsafeBytes {
            texture.replace(region: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: w * 4)
        }
        let source = renderer.source(for: texture)
        for age in MonitorAge.allCases {
            let job = LensRenderer.Job(parts: [.init(source: source, region: RenderRegion(origin: .zero), nonRetinaBlock: 2)],
                                       width: w, height: h, filter: MonitorFilter(profile: profile, age: age))
            if let px = renderer.renderNow(job), let img = LensRenderer.image(fromBGRA: px, w, h) {
                aged[age] = NSImage(cgImage: img, size: SampleScreen.size)
            }
        }
    }

    /// The image as sRGB-encoded BGRA bytes, like a screen capture.
    private static func bgra(_ cg: CGImage) -> [UInt8]? {
        let w = cg.width, h = cg.height
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        let info = CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        let ok = bytes.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: info) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return ok ? bytes : nil
    }
}

// MARK: - Welcome (first run, step 1)

/// The first thing a new user sees (PRD §5.2, DT2): a live before/after of the sample
/// screen through the most common office monitor, ageing in front of them, then Continue.
struct WelcomeView: View {
    @ObservedObject var model: LensModel
    let renderer: LensRenderer?

    @StateObject private var demo = DemoImages()
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ViewThatFits(in: .vertical) {
            content(demoWidth: 560, features: true)
            content(demoWidth: 440, features: true)
            content(demoWidth: 380, features: false)
            ScrollView { content(demoWidth: 380, features: false) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            demo.make(renderer: renderer, profile: model.library.firstRunDefault)
            appeared = true
        }
    }

    private func content(demoWidth: CGFloat, features: Bool) -> some View {
        VStack(spacing: 0) {
            DemoSplitView(demo: demo, monitorName: model.library.firstRunDefault?.displayName ?? "Office monitor",
                          width: demoWidth)
                .entrance(appeared, step: 0, reduceMotion)

            VStack(spacing: 10) {
                Text("See what your users see.")
                    .font(.system(size: 28, weight: .bold))
                Text("Crappy Monitor puts a lens over your screen that shows it the way office monitors do: duller colours, softer text, tired backlights.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 520)
            }
            .padding(.top, 26)
            .entrance(appeared, step: 1, reduceMotion)

            if features {
                HStack(alignment: .top, spacing: 26) {
                    Feature(symbol: "display.2", title: "Real office monitors",
                            text: "The ten models large organisations buy most, from datasheets and display data.")
                    Feature(symbol: "clock.arrow.circlepath", title: "Watch them age",
                            text: "Dimmer backlights, yellowing and dark corners after 3, 6 or 10 years.")
                    Feature(symbol: "option", title: "Hold ⌥ to compare",
                            text: "Flip back to your own screen at any moment.")
                }
                .padding(.top, 24)
                .entrance(appeared, step: 2, reduceMotion)
            }

            VStack(spacing: 10) {
                Button {
                    model.continueFromWelcome?()
                } label: {
                    Text("Continue").frame(minWidth: 140)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)

                Text("Next, macOS asks you to allow Screen Recording. The lens only looks: nothing is recorded, saved or sent.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            .padding(.top, 26)
            .entrance(appeared, step: 3, reduceMotion)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }
}

private struct Feature: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(.tint)
                .frame(height: 28)
                .accessibilityHidden(true)
            Text(title).font(.headline)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 176)
        .accessibilityElement(children: .combine)
    }
}

private extension View {
    /// Staggered fade-and-rise when the intro appears; a plain fade with Reduce Motion.
    func entrance(_ shown: Bool, step: Int, _ reduceMotion: Bool) -> some View {
        self
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .animation(reduceMotion ? .easeOut(duration: 0.2)
                                    : .spring(response: 0.7, dampingFraction: 0.86).delay(0.08 * Double(step) + 0.05),
                       value: shown)
    }
}

// MARK: - The before/after demo

/// Left of the divider: the sample as the Mac shows it. Right: through the monitor at the
/// current age. The divider sweeps in once, then the monitor ages New → 10 years in a
/// loop. Drag the divider, or click an age, to take over.
private struct DemoSplitView: View {
    @ObservedObject var demo: DemoImages
    let monitorName: String
    let width: CGFloat

    @State private var split: CGFloat = 1        // divider position, 0…1 from the left
    @State private var age: MonitorAge = .new
    @State private var cycling = true
    @State private var dragging = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var height: CGFloat { width * SampleScreen.size.height / SampleScreen.size.width }

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .trailing) {
                if let original = demo.original {
                    Image(nsImage: original).resizable().interpolation(.high)
                        .frame(width: width, height: height)
                } else {
                    Rectangle().fill(.quaternary)
                }
                // The monitor's half: the full aged image, clipped to the right of the divider.
                ZStack(alignment: .trailing) {
                    if let aged = demo.aged[age] {
                        Image(nsImage: aged).resizable().interpolation(.high)
                            .frame(width: width, height: height)
                            .transition(.opacity)
                            .id(age)
                    }
                }
                .frame(width: max(0, width * (1 - split)), height: height, alignment: .trailing)
                .clipped()
                labels
                divider
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.separator, lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                dragging = true
                split = min(max(g.location.x / width, 0.04), 0.96)
            }.onEnded { _ in dragging = false })
            .accessibilityElement()
            .accessibilityLabel("Example: a dashboard on your Mac next to the same dashboard on a \(monitorName), \(age.label.lowercased()).")
            .accessibilityAdjustableAction { direction in
                let all = MonitorAge.allCases
                let i = all.firstIndex(of: age) ?? 0
                cycling = false
                switch direction {
                case .increment: age = all[min(i + 1, all.count - 1)]
                case .decrement: age = all[max(i - 1, 0)]
                @unknown default: break
                }
            }

            ageSelector
        }
        .task { await run() }
    }

    private var labels: some View {
        HStack {
            DemoCapsule(text: "Your Mac")
                .opacity(split > 0.18 ? 1 : 0)
            Spacer()
            DemoCapsule(text: "\(monitorName) · \(age.label)")
                .transaction { $0.animation = nil }   // swap the text, don't blend it
                .opacity(split < 0.72 ? 1 : 0)
                .animation(.easeOut(duration: 0.2), value: split < 0.72)
        }
        .padding(10)
        .frame(width: width, height: height, alignment: .bottom)
    }

    private var divider: some View {
        ZStack {
            Rectangle().fill(.white).frame(width: 2).shadow(color: .black.opacity(0.25), radius: 2)
            Circle().fill(.regularMaterial)
                .frame(width: 30, height: 30)
                .overlay(Image(systemName: "arrow.left.and.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary))
                .shadow(color: .black.opacity(0.2), radius: 4, y: 1)
                .scaleEffect(dragging ? 1.12 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragging)
        }
        .frame(width: 30, height: height)
        .position(x: width * split, y: height / 2)
        .opacity(split > 0.99 ? 0 : 1)
    }

    private var ageSelector: some View {
        HStack(spacing: 4) {
            ForEach(MonitorAge.allCases) { a in
                Button {
                    cycling = false
                    withAnimation(.easeInOut(duration: 0.35)) { age = a }
                } label: {
                    Text(a.label)
                        .font(.callout.weight(a == age ? .semibold : .regular))
                        .foregroundStyle(a == age ? .primary : .secondary)
                        .padding(.horizontal, 9).padding(.vertical, 3)
                        .background(a == age ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: age)
        .accessibilityHidden(true)   // the demo itself is adjustable
    }

    /// Sweep the divider in, then age the monitor until the user takes over.
    private func run() async {
        try? await Task.sleep(nanoseconds: 700_000_000)
        if reduceMotion {
            split = 0.5
        } else {
            withAnimation(.spring(response: 1.2, dampingFraction: 0.82)) { split = 0.5 }
        }
        try? await Task.sleep(nanoseconds: 1_400_000_000)
        let all = MonitorAge.allCases
        while !Task.isCancelled {
            guard cycling else { return }
            let i = all.firstIndex(of: age) ?? 0
            let next = all[(i + 1) % all.count]
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.6)) { age = next }
            // Linger on 10 years and on New, so both ends register.
            let hold: UInt64 = (next == .ten || next == .new) ? 2_600_000_000 : 1_500_000_000
            try? await Task.sleep(nanoseconds: hold)
        }
    }
}

private struct DemoCapsule: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(.regularMaterial, in: Capsule())
            .environment(\.colorScheme, .dark)
    }
}

// MARK: - Step 2: turn it on in System Settings

/// After Continue (or a later launch without permission): how to turn it on, while the
/// app waits and notices the switch by itself.
struct PermissionStepsView: View {
    var body: some View {
        ViewThatFits(in: .vertical) {
            content(full: true)
            content(full: false)
            ScrollView { content(full: false) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func content(full: Bool) -> some View {
        VStack(spacing: 18) {
            if full {
                Image(systemName: "rectangle.dashed.badge.record")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            VStack(spacing: 8) {
                Text("Turn on Screen Recording").font(.title2.weight(.semibold))
                Text("macOS keeps your screen private until you allow an app to see it. The lens only looks: nothing is recorded, saved or sent.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 460)
            }
            VStack(alignment: .leading, spacing: 10) {
                StepRow(n: 1, text: "Open Privacy & Security › Screen Recording in System Settings.")
                StepRow(n: 2, text: "Turn on Crappy Monitor.")
                StepRow(n: 3, text: "Choose Quit & Reopen when macOS asks.")
            }
            .padding(16)
            .frame(maxWidth: 440, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            HStack(spacing: 12) {
                Button("Learn More") { NSWorkspace.shared.open(ScreenRecordingPermission.helpURL) }
                Button("Open System Settings…") { ScreenRecordingPermission.openSettings() }
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)

            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Waiting for permission…").font(.callout).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
        .padding(full ? 28 : 16)
        .frame(maxWidth: .infinity)
    }
}

private struct StepRow: View {
    let n: Int
    let text: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(n)")
                .font(.callout.weight(.semibold).monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(.tint))
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Step 3: relaunch

/// Turned on, but macOS only lets this process use it after a relaunch (T11).
struct RelaunchView: View {
    @ObservedObject var model: LensModel
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .green)
                .scaleEffect(shown || reduceMotion ? 1 : 0.4)
                .opacity(shown ? 1 : 0)
                .animation(.spring(response: 0.45, dampingFraction: 0.6), value: shown)
                .accessibilityHidden(true)
            Text("Permission granted").font(.title2.weight(.semibold))
            Text("Relaunch Crappy Monitor to start the lens.")
                .foregroundStyle(.secondary)
            Button {
                model.relaunch?()
            } label: {
                Text("Relaunch").frame(minWidth: 120)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { shown = true }
    }
}
