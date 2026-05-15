import Combine
import Foundation

class FilterSettings: ObservableObject {
    @Published var isEnabled: Bool = true

    @Published var brightness: Double = 0.0       // -1.0 … 0.0
    @Published var contrast: Double = 1.0         // 0.5 … 1.5
    @Published var colorTempShift: Double = 6500  // 1667K … 25000K
    @Published var gammaExponent: Double = 1.0    // 0.8 … 1.4
    @Published var blackLevel: Double = 0.0       // 0.0 … 0.15
    @Published var gammaDrift: Double = 0.0       // 0.0 … 0.5 — midtone compression (preset-only)
    @Published var pixelSimulation: Bool = false
    @Published var lowResModeAvailable: Bool = false

    // Tracks which preset is currently applied; nil if sliders were moved manually.
    @Published var activePresetID: String? = nil

    // Set by AppDelegate when the A/B Option-key compare is held.
    @Published var isABActive: Bool = false
}
