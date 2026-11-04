import Foundation
import simd

/// Global age control (PRD §2, §7.3).
enum MonitorAge: Int, CaseIterable, Identifiable, Codable, Hashable {
    case new = 0, three = 3, six = 6, ten = 10

    var id: Int { rawValue }
    var years: Double { Double(rawValue) }
    var label: String { self == .new ? "New" : "\(rawValue) years" }
    var phrase: String { self == .new ? "Shown as new" : "Shown at \(rawValue) years old" }
}

/// The one place that turns a monitor profile, an age and Adjust edits into filter
/// parameters (PRD §6, §7.2–7.3). `apply(_:)` is the CPU reference of the pixel maths;
/// the Metal shader mirrors it and tests compare the two (PRD §10).
///
/// Signal path for one sRGB-encoded pixel:
///   1. panel tone curve per channel (gamma, TN midtone drift, VA shadow crush) → linear
///   2. the panel's own primaries → sRGB linear (gamut matrix)
///   3. white point (warm drift with age) via the Kang multipliers
///   4. panel black floor (1 / contrast), backlight wear and reflected office light,
///      normalised so a new monitor's white stays at 1
///   5. clamp and encode back to sRGB for the Mac display
struct MonitorFilter: Hashable {

    /// Edits from the Adjust popover; nil means "as the profile says".
    struct Edits: Hashable, Codable {
        var backlight: Double?          // multiplies backlight output, 0.2…1
        var contrastRatio: Double?      // panel static contrast, 100…5000
        var colorTemperature: Double?   // white point in kelvin, 3000…9000
        var gamma: Double?              // panel gamma, 1.8…2.6
        var officeLight: Double?        // multiplies reflected office light, 0…3
        var nonRetina: Bool?

        static let backlightRange = 0.2...1.0
        static let contrastRange = 100.0...5000.0
        static let colorTemperatureRange = 3000.0...9000.0
        static let gammaRange = 1.8...2.6
        static let officeLightRange = 0.0...3.0

        var isEmpty: Bool { self == Edits() }
    }

    /// Starting values, to be calibrated with a colourimeter later (PRD §7.3, Q4).
    enum Constants {
        static let panelGamma = 2.2               // every library EDID reports 2.2
        static let ledWearPerYear = 0.015         // ≈ 0.85 after 10 years [estimated]
        static let ccflWearPerYear = 0.030        // ≈ 0.70 after 10 years [estimated]
        static let minimumWear = 0.2
        static let officeReflection = 1.6         // cd/m², ~500 lux on a matte panel [estimated]
        static let warmDriftPerYear = 60.0        // kelvin [estimated]
        static let cornerFalloffPerYear = 0.01    // 10 % at 10 years [estimated]
        static let tnMidtoneDrift = 0.2           // extra gamma at mid-grey on TN panels
        static let vaShadowCrush = 0.6            // extra gamma just above black on VA panels
        static let vaShadowKnee = 0.1             // signal level where VA crush fades out
    }

    let profile: MonitorProfile
    let age: MonitorAge
    let edits: Edits

    init(profile: MonitorProfile, age: MonitorAge = .six, edits: Edits = Edits()) {
        self.profile = profile
        self.age = age
        self.edits = edits
    }

    static func == (a: MonitorFilter, b: MonitorFilter) -> Bool {
        a.profile.id == b.profile.id && a.age == b.age && a.edits == b.edits
    }

    func hash(into h: inout Hasher) {
        h.combine(profile.id); h.combine(age); h.combine(edits)
    }

    // MARK: Parameters

    var gamma: Double { edits.gamma ?? Constants.panelGamma }

    var midtoneDrift: Double { profile.panelType == .tn ? Constants.tnMidtoneDrift : 0 }

    var shadowCrush: Double { profile.panelType == .va ? Constants.vaShadowCrush : 0 }

    /// Panel black relative to panel white, in linear light.
    var blackFloor: Double { 1 / max(edits.contrastRatio ?? profile.contrastRatio, 1) }

    /// Backlight output relative to new: w(t) = 1 − k·t (PRD §7.3).
    var wear: Double {
        let k = profile.backlight == .ccfl ? Constants.ccflWearPerYear : Constants.ledWearPerYear
        let aged = max(Constants.minimumWear, 1 - k * age.years)
        return aged * (edits.backlight ?? 1)
    }

    /// Reflected office light relative to the new monitor's white: a = 1.6 cd/m² / max brightness.
    var officeLight: Double {
        Constants.officeReflection / max(profile.maxBrightness, 1) * (edits.officeLight ?? 1)
    }

    var newWhiteTemperature: Double { WhitePoint.correlatedTemperature(of: profile.primaries.white) }

    /// T(t) = T_new − 60 K · t, unless Adjust sets it.
    var whiteTemperature: Double {
        let t = edits.colorTemperature ?? (newWhiteTemperature - Constants.warmDriftPerYear * age.years)
        return min(max(t, 1667), 25000)
    }

    /// Per-channel gain that moves the white from T_new to T(t); exactly 1 when unchanged.
    var whiteMultipliers: SIMD3<Double> {
        let now = WhitePoint.multipliers(for: whiteTemperature)
        let new = WhitePoint.multipliers(for: newWhiteTemperature)
        return SIMD3(Double(now.r / new.r), Double(now.g / new.g), Double(now.b / new.b))
    }

    /// Brightness loss towards the corners of the display under the lens: u(t) = 0.01 · t.
    var cornerFalloff: Double { Constants.cornerFalloffPerYear * age.years }

    /// Every library monitor is ≈ 90–100 ppi, so non-retina is on unless Adjust turns it off.
    var nonRetina: Bool { edits.nonRetina ?? true }

    /// Physical display pixels per simulated monitor pixel, for a display of `displayPPI`.
    func blockSize(displayPPI: Double) -> Double {
        let ppi = profile.pixelsPerInch
        guard ppi > 0, nonRetina else { return 1 }
        return max(1, displayPPI / ppi)
    }

    /// Linear RGB of the monitor's primaries → linear sRGB (PRD §7.2, gamut).
    var gamutMatrix: simd_double3x3 {
        Self.rgbToXYZ(.sRGB).inverse * Self.rgbToXYZ(profile.primaries)
    }

    // MARK: Pixel maths (CPU reference)

    /// Panel tone curve: encoded signal → linear light, per channel.
    func panelLinear(_ v: Double) -> Double {
        let v = min(max(v, 0), 1)
        var g = gamma + midtoneDrift * (1 - abs(2 * v - 1))
        if shadowCrush > 0, v < Constants.vaShadowKnee {
            g += shadowCrush * (1 - v / Constants.vaShadowKnee)
        }
        return pow(v, g)
    }

    /// One sRGB-encoded pixel (0…1 per channel) as this monitor shows it, sRGB-encoded.
    /// `gamut: false` skips the matrix (the prototype's per-channel renderer, until T4).
    func apply(_ rgb: SIMD3<Double>, gamut: Bool = true) -> SIMD3<Double> {
        var lin = SIMD3(panelLinear(rgb.x), panelLinear(rgb.y), panelLinear(rgb.z))
        if gamut { lin = gamutMatrix * lin }
        lin *= whiteMultipliers
        let b = blackFloor, w = wear, a = officeLight
        var out = (w * (b + (1 - b) * lin) + a) / (1 + a)
        out = simd_clamp(out, SIMD3(repeating: 0), SIMD3(repeating: 1))
        return SIMD3(Self.encode(out.x), Self.encode(out.y), Self.encode(out.z))
    }

    /// Output for the 256 grey levels (r = g = b), per channel. Used for the table
    /// invariants (regression contract, Vraag 12).
    func greyRamp() -> (r: [Double], g: [Double], b: [Double]) {
        var r = [Double](), g = [Double](), b = [Double]()
        r.reserveCapacity(256); g.reserveCapacity(256); b.reserveCapacity(256)
        for i in 0..<256 {
            let v = Double(i) / 255
            let o = apply(SIMD3(v, v, v))
            r.append(o.x); g.append(o.y); b.append(o.z)
        }
        return (r, g, b)
    }

    /// Per-channel 3 × 256 tables without the gamut matrix: what the prototype's
    /// per-channel shader and thumbnails can apply until the T4 renderer lands.
    func channelTables() -> (r: [Float], g: [Float], b: [Float]) {
        var r = [Float](), g = [Float](), b = [Float]()
        for i in 0..<256 {
            let v = Double(i) / 255
            r.append(Float(apply(SIMD3(v, 0, 0), gamut: false).x))
            g.append(Float(apply(SIMD3(0, v, 0), gamut: false).y))
            b.append(Float(apply(SIMD3(0, 0, v), gamut: false).z))
        }
        return (r, g, b)
    }

    // MARK: Helpers

    static func encode(_ l: Double) -> Double {
        l <= 0.0031308 ? 12.92 * l : 1.055 * pow(l, 1 / 2.4) - 0.055
    }

    static func decode(_ v: Double) -> Double {
        v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
    }

    /// RGB → XYZ for a set of primaries, white normalised to Y = 1.
    static func rgbToXYZ(_ p: MonitorProfile.Primaries) -> simd_double3x3 {
        func column(_ c: MonitorProfile.XY) -> SIMD3<Double> { SIMD3(c.x / c.y, 1, (1 - c.x - c.y) / c.y) }
        let m = simd_double3x3(columns: (column(p.red), column(p.green), column(p.blue)))
        let s = m.inverse * column(p.white)
        return simd_double3x3(columns: (m.columns.0 * s.x, m.columns.1 * s.y, m.columns.2 * s.z))
    }
}
