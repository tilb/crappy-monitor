import Foundation

/// One monitor in the library (PRD §7.1). Values come from datasheets and EDID; see
/// design/monitor-research.md for the research and sources.
struct MonitorProfile: Codable, Identifiable, Equatable {
    enum PanelType: String, Codable { case ips = "IPS", tn = "TN", va = "VA", pls = "PLS" }
    enum Backlight: String, Codable { case wled = "W-LED", ccfl = "CCFL" }

    /// CIE 1931 xy chromaticity.
    struct XY: Codable, Equatable {
        var x: Double
        var y: Double
        init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            x = try c.decode(Double.self); y = try c.decode(Double.self)
        }
        func encode(to encoder: Encoder) throws {
            var c = encoder.unkeyedContainer()
            try c.encode(x); try c.encode(y)
        }
    }

    struct Primaries: Codable, Equatable {
        var red: XY, green: XY, blue: XY, white: XY

        /// The sRGB / Rec. 709 standard with a D65 white.
        static let sRGB = Primaries(red: XY(0.64, 0.33), green: XY(0.30, 0.60),
                                    blue: XY(0.15, 0.06), white: XY(0.3127, 0.3290))
    }

    let id: String
    let brand: String
    let model: String
    let released: Int?
    let panelType: PanelType
    let backlight: Backlight
    let sizeInches: Double
    let resolution: [Int]            // [width, height]
    let contrastRatio: Double
    let maxBrightness: Double        // cd/m²
    let gamutSpec: String?           // as the datasheet states it, nil if not found
    let primaries: Primaries
    let sources: [String: String]
    let estimated: [String]          // field names whose value is estimated

    /// Brand + model, the UI label.
    var displayName: String { "\(brand) \(model)" }

    var pixelsPerInch: Double {
        guard resolution.count == 2, sizeInches > 0 else { return 0 }
        let w = Double(resolution[0]), h = Double(resolution[1])
        return (w * w + h * h).squareRoot() / sizeInches
    }

    func isEstimated(_ field: String) -> Bool { estimated.contains(field) }

    /// Share of the sRGB triangle this monitor's primaries cover (0…1), from EDID.
    var sRGBCoverage: Double { Gamut.coverage(of: primaries, within: .sRGB) }
}

/// The bundled library (`Monitors.json`), schema version 2.
struct MonitorLibrary: Codable {
    static let supportedSchemaVersion = 2

    let schemaVersion: Int
    let monitors: [MonitorProfile]

    enum LoadError: Error, Equatable { case missingFile, unsupportedSchema(Int) }

    static func decode(_ data: Data) throws -> MonitorLibrary {
        let lib = try JSONDecoder().decode(MonitorLibrary.self, from: data)
        guard lib.schemaVersion == supportedSchemaVersion else {
            throw LoadError.unsupportedSchema(lib.schemaVersion)
        }
        return lib
    }

    static func bundled(_ bundle: Bundle = .main) throws -> MonitorLibrary {
        guard let url = bundle.url(forResource: "Monitors", withExtension: "json") else {
            throw LoadError.missingFile
        }
        return try decode(Data(contentsOf: url))
    }

    func monitor(_ id: String?) -> MonitorProfile? { monitors.first { $0.id == id } }

    /// Research rank 1, the first-run default (PRD §8.2).
    var firstRunDefault: MonitorProfile? { monitors.first }
}

/// Geometry on the CIE 1931 xy diagram.
enum Gamut {
    static func coverage(of p: MonitorProfile.Primaries, within ref: MonitorProfile.Primaries) -> Double {
        let a = triangle(ref), b = triangle(p)
        let overlap = clip(a, by: b)
        return area(overlap) / area(a)
    }

    private typealias Point = (x: Double, y: Double)

    private static func triangle(_ p: MonitorProfile.Primaries) -> [Point] {
        ccw([(p.red.x, p.red.y), (p.green.x, p.green.y), (p.blue.x, p.blue.y)])
    }

    private static func ccw(_ t: [Point]) -> [Point] {
        let cross = (t[1].x - t[0].x) * (t[2].y - t[0].y) - (t[1].y - t[0].y) * (t[2].x - t[0].x)
        return cross > 0 ? t : t.reversed()
    }

    private static func area(_ poly: [Point]) -> Double {
        guard poly.count >= 3 else { return 0 }
        var s = 0.0
        for i in poly.indices {
            let a = poly[i], b = poly[(i + 1) % poly.count]
            s += a.x * b.y - b.x * a.y
        }
        return abs(s) / 2
    }

    /// Sutherland–Hodgman: the part of `subject` inside the convex `clipper`.
    private static func clip(_ subject: [Point], by clipper: [Point]) -> [Point] {
        func inside(_ p: Point, _ a: Point, _ b: Point) -> Bool {
            (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x) >= 0
        }
        func intersect(_ p: Point, _ q: Point, _ a: Point, _ b: Point) -> Point {
            let d = (p.x - q.x) * (a.y - b.y) - (p.y - q.y) * (a.x - b.x)
            let t = ((p.x - a.x) * (a.y - b.y) - (p.y - a.y) * (a.x - b.x)) / d
            return (p.x + t * (q.x - p.x), p.y + t * (q.y - p.y))
        }
        var output = subject
        for i in clipper.indices {
            let a = clipper[i], b = clipper[(i + 1) % clipper.count]
            let input = output
            output = []
            for j in input.indices {
                let p = input[j], q = input[(j + 1) % input.count]
                if inside(q, a, b) {
                    if !inside(p, a, b) { output.append(intersect(p, q, a, b)) }
                    output.append(q)
                } else if inside(p, a, b) {
                    output.append(intersect(p, q, a, b))
                }
            }
            if output.isEmpty { break }
        }
        return output
    }
}
