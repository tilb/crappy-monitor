import Foundation
import os.log

private let log = Logger(subsystem: "com.murkymonitor.app", category: "PresetsStore")

class PresetsStore: ObservableObject {
    @Published private(set) var presets: [DegradationPreset] = []

    init() {
        load()
    }

    private func load() {
        guard let url = Bundle.main.url(forResource: "Presets", withExtension: "json") else {
            log.error("Presets.json not found in bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            presets = try JSONDecoder().decode([DegradationPreset].self, from: data)
            log.info("Loaded \(self.presets.count) presets")
        } catch {
            log.error("Failed to load Presets.json: \(error)")
            presets = []
        }
    }
}
