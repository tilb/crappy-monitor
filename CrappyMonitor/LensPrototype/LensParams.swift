import CoreGraphics
import Foundation

// LENS PROTOTYPE — throwaway. Everything in LensPrototype/ can be deleted as a unit.

/// Global age control, applied on top of any monitor (HANDOFF §2).
enum MonitorAge: Int, CaseIterable, Identifiable {
    case new = 0, three = 3, six = 6, ten = 10

    var id: Int { rawValue }
    var label: String { self == .new ? "New" : "\(rawValue) years" }
    var phrase: String { self == .new ? "Shown as new" : "Shown at \(rawValue) years old" }
}

/// The filter parameters for one monitor, as plain values. Lens, thumbnails and
/// Whole Screen all go through `tables()`, which is `GammaController.buildTables`,
/// so the two pipelines share one formula.
struct LensParams: Hashable {
    var brightness = 0.0
    var contrast = 1.0
    var colorTemp = 6500.0
    var gamma = 1.0
    var blackLevel = 0.0
    var gammaDrift = 0.0
    var nonRetina = false

    // Same ranges as the Adjust sliders.
    static let brightnessRange = -1.0...0.0
    static let contrastRange = 0.5...1.5
    static let colorTempRange = 3000.0...9000.0
    static let gammaRange = 0.8...1.4
    static let blackLevelRange = 0.0...0.15

    init() {}

    init(preset: DegradationPreset) {
        let s = FilterSettings()
        preset.apply(to: s)   // reuses the existing NaN guards
        brightness = s.brightness
        contrast = s.contrast
        colorTemp = s.colorTempShift
        gamma = s.gammaExponent
        blackLevel = s.blackLevel
        gammaDrift = s.gammaDrift
        nonRetina = preset.simulateLowDpi
    }

    /// Placeholder wear model from HANDOFF §5, tuned by eye later.
    func aged(_ age: MonitorAge) -> LensParams {
        let years = Double(age.rawValue)
        var p = self
        p.brightness = (brightness - 0.015 * years).clamped(to: Self.brightnessRange)
        p.contrast = (contrast - 0.02 * years).clamped(to: Self.contrastRange)
        p.colorTemp = (colorTemp - 60 * years).clamped(to: Self.colorTempRange)
        p.blackLevel = (blackLevel + 0.004 * years).clamped(to: Self.blackLevelRange)
        return p
    }

    func write(to s: FilterSettings) {
        s.brightness = brightness
        s.contrast = contrast
        s.colorTempShift = colorTemp
        s.gammaExponent = gamma
        s.blackLevel = blackLevel
        s.gammaDrift = gammaDrift
    }

    func tables() -> (r: [CGGammaValue], g: [CGGammaValue], b: [CGGammaValue]) {
        let s = FilterSettings()
        write(to: s)
        let (r, g, b) = GammaController().buildTables(s)
        return (r, g, b)
    }
}

/// What the user changed in the Adjust popover. nil = not touched.
struct LensOverrides: Equatable {
    var brightness: Double?
    var contrast: Double?
    var colorTemp: Double?
    var gamma: Double?
    var blackLevel: Double?
    var nonRetina: Bool?

    var isEmpty: Bool { self == LensOverrides() }

    func applied(to base: LensParams) -> LensParams {
        var p = base
        if let v = brightness { p.brightness = v }
        if let v = contrast { p.contrast = v }
        if let v = colorTemp { p.colorTemp = v }
        if let v = gamma { p.gamma = v }
        if let v = blackLevel { p.blackLevel = v }
        if let v = nonRetina { p.nonRetina = v }
        return p
    }
}

extension Comparable {
    func clamped(to r: ClosedRange<Self>) -> Self { min(max(self, r.lowerBound), r.upperBound) }
}
