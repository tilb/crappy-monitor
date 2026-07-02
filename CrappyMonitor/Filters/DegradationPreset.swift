import Foundation

struct DegradationPreset: Identifiable, Decodable {
    let id: String
    let name: String
    let brightness: Double
    let contrast: Double
    let colorTempShift: Double
    let gammaExponent: Double
    let blackLevel: Double
    let gammaDrift: Double  // midtone compression, preset-only (not surfaced in UI)

    // Physical spec metadata — display context, not simulation parameters.
    let year: Int?
    let resolution: String?
    let dpi: Int?
    let refreshHz: Int?
    let simulateLowDpi: Bool

    private enum CodingKeys: String, CodingKey {
        case id, name, brightness, contrast, colorTempShift
        case gammaExponent, blackLevel, gammaDrift
        case year, resolution, dpi, refreshHz, simulateLowDpi
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decode(String.self, forKey: .id)
        name           = try c.decode(String.self, forKey: .name)
        brightness     = try c.decode(Double.self, forKey: .brightness)
        contrast       = try c.decode(Double.self, forKey: .contrast)
        colorTempShift = try c.decode(Double.self, forKey: .colorTempShift)
        gammaExponent  = try c.decodeIfPresent(Double.self, forKey: .gammaExponent) ?? 1.0
        blackLevel     = try c.decodeIfPresent(Double.self, forKey: .blackLevel) ?? 0.0
        gammaDrift     = try c.decodeIfPresent(Double.self, forKey: .gammaDrift) ?? 0.0
        year           = try c.decodeIfPresent(Int.self, forKey: .year)
        resolution     = try c.decodeIfPresent(String.self, forKey: .resolution)
        dpi            = try c.decodeIfPresent(Int.self, forKey: .dpi)
        refreshHz      = try c.decodeIfPresent(Int.self, forKey: .refreshHz)
        simulateLowDpi = try c.decodeIfPresent(Bool.self, forKey: .simulateLowDpi) ?? false
    }

    func apply(to settings: FilterSettings) {
        // NaN guard: only apply finite values to avoid corrupting gamma tables.
        settings.brightness     = brightness.isFinite     ? brightness     : 0.0
        settings.contrast       = contrast.isFinite       ? contrast       : 1.0
        settings.colorTempShift = colorTempShift.isFinite ? colorTempShift : 6500.0
        settings.gammaExponent  = gammaExponent.isFinite  ? gammaExponent  : 1.0
        settings.blackLevel     = blackLevel.isFinite     ? blackLevel     : 0.0
        settings.gammaDrift     = gammaDrift.isFinite     ? gammaDrift     : 0.0
        settings.activePresetID = id
    }

    // Human-readable subtitle: "1920 × 1080  •  96 DPI  •  60 Hz"
    var specSubtitle: String? {
        var parts: [String] = []
        if let res = resolution {
            let formatted = res.replacingOccurrences(of: "x", with: " × ")
            parts.append(formatted)
        }
        if let d = dpi { parts.append("\(d) DPI") }
        if let hz = refreshHz { parts.append("\(hz) Hz") }
        return parts.isEmpty ? nil : parts.joined(separator: "  •  ")
    }
}
