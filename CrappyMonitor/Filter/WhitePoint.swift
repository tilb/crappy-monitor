import Foundation

/// White point maths. `multipliers(for:)` is v1's `GammaController.colorMultipliers(for:)`,
/// moved unchanged (PRD §6.1, regression contract Vraag 12).
enum WhitePoint {
    // Kang et al. 2002 — correlated color temperature to per-channel RGB multipliers.
    // Uses Bradford chromatic adaptation from the target white point to D65.
    static func multipliers(for kelvin: Double) -> (r: Float, g: Float, b: Float) {
        // Clamp to Kang's valid range.
        let T = max(1667.0, min(25000.0, kelvin))

        // x chromaticity — two piecewise polynomials.
        let x: Double
        if T <= 4000.0 {
            x = -0.2661239e9 / (T * T * T)
              - 0.2343589e6 / (T * T)
              + 0.8776956e3 / T
              + 0.179910
        } else {
            x = -3.0258469e9 / (T * T * T)
              + 2.1070379e6 / (T * T)
              + 0.2226347e3 / T
              + 0.240390
        }

        // y chromaticity — three piecewise polynomials.
        let y: Double
        if T <= 2222.0 {
            y = -1.1063814  * x * x * x
              - 1.34811020  * x * x
              + 2.18555832  * x
              - 0.20219683
        } else if T <= 4000.0 {
            y = -0.9549476  * x * x * x
              - 1.37418593  * x * x
              + 2.09137015  * x
              - 0.16748867
        } else {
            y =  3.0817580  * x * x * x
              - 5.87338670  * x * x
              + 3.75112997  * x
              - 0.37001483
        }

        guard y > 0 else { return (1, 1, 1) }

        // XYZ (Y = 1)
        let X = x / y
        let Y = 1.0
        let Z = (1.0 - x - y) / y

        // XYZ → linear sRGB (D65 primaries, IEC 61966-2-1).
        let rLin =  3.2406 * X - 1.5372 * Y - 0.4986 * Z
        let gLin = -0.9689 * X + 1.8758 * Y + 0.0415 * Z
        let bLin =  0.0557 * X - 0.2040 * Y + 1.0570 * Z

        // Normalise so the brightest channel = 1.0; clamp to [0.5, 1.5].
        let peak = max(rLin, gLin, bLin)
        guard peak > 0 else { return (1, 1, 1) }

        let rN = rLin / peak
        let gN = gLin / peak
        let bN = bLin / peak

        // D65 reference (pre-computed from Kang at 6500K) so that 6500K yields exactly (1,1,1).
        let rD65 = 1.000000, gD65 = 0.942631, bD65 = 0.993846

        let rM = Float(min(max(rN / rD65, 0.5), 1.5))
        let gM = Float(min(max(gN / gD65, 0.5), 1.5))
        let bM = Float(min(max(bN / bD65, 0.5), 1.5))

        return (rM, gM, bM)
    }

    /// Correlated colour temperature of a white point (McCamy 1992), in kelvin.
    static func correlatedTemperature(of white: MonitorProfile.XY) -> Double {
        let n = (white.x - 0.3320) / (0.1858 - white.y)
        return 449 * n * n * n + 3525 * n * n + 6823.3 * n + 5520.33
    }
}
