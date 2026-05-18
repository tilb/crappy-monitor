import AppKit
import CoreGraphics
import Foundation
import os.log

private let log = Logger(subsystem: "com.murkymonitor.app", category: "PresetsStore")

class PresetsStore: ObservableObject {
    @Published private(set) var presets: [DegradationPreset] = []
    @Published private(set) var thumbnails: [String: NSImage] = [:]

    struct PresetGroup: Identifiable {
        let id: String          // e.g. "2010s", "Other"
        let presets: [DegradationPreset]
    }

    // Presets grouped by decade descending, nil-year entries in "Other" at the bottom.
    var groupedByDecade: [PresetGroup] {
        var buckets: [String: [DegradationPreset]] = [:]
        for preset in presets {
            let key: String
            if let year = preset.year {
                let decade = (year / 10) * 10
                key = "\(decade)s"
            } else {
                key = "Other"
            }
            buckets[key, default: []].append(preset)
        }
        let sorted = buckets.sorted { a, b in
            if a.key == "Other" { return false }
            if b.key == "Other" { return true }
            return a.key > b.key  // "2020s" before "2010s" before "2000s"
        }
        return sorted.map { key, group in
            PresetGroup(id: key, presets: group.sorted { $0.name < $1.name })
        }
    }

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
            renderThumbnailsAsync()
        } catch {
            log.error("Failed to load Presets.json: \(error)")
            presets = []
        }
    }

    private func renderThumbnailsAsync() {
        let presetsSnapshot = presets
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let gc = GammaController()
            let refPixels = PresetsStore.makeReferencePixels()
            var rendered: [String: NSImage] = [:]

            for preset in presetsSnapshot {
                let settings = FilterSettings()
                preset.apply(to: settings)
                let (r, g, b) = gc.buildTables(settings)
                var pixels = refPixels
                PresetsStore.applyGamma(to: &pixels, rTable: r, gTable: g, bTable: b)
                if let img = PresetsStore.makeImage(from: pixels) {
                    rendered[preset.id] = img
                }
            }

            DispatchQueue.main.async { [weak self] in
                self?.thumbnails = rendered
            }
        }
    }

    // MARK: - Thumbnail rendering helpers

    // 128×128 reference image: grayscale gradient (top), colour patches (bottom).
    static func makeReferencePixels() -> [UInt8] {
        let width = 128, height = 128
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                let (r, g, b): (UInt8, UInt8, UInt8)
                switch y {
                case 0..<56:
                    // Grayscale ramp: shadows → highlights
                    let v = UInt8(x * 255 / (width - 1))
                    (r, g, b) = (v, v, v)
                case 56..<72:
                    // Warm skin-tone band
                    (r, g, b) = (220, 175, 140)
                case 72..<88:
                    // Red
                    (r, g, b) = (200, 55, 55)
                case 88..<104:
                    // Green
                    (r, g, b) = (55, 180, 55)
                default:
                    // Blue
                    (r, g, b) = (55, 100, 200)
                }
                pixels[i] = r; pixels[i+1] = g; pixels[i+2] = b
                // alpha already 255
            }
        }
        return pixels
    }

    static func applyGamma(to pixels: inout [UInt8],
                           rTable: [CGGammaValue],
                           gTable: [CGGammaValue],
                           bTable: [CGGammaValue]) {
        var i = 0
        while i < pixels.count {
            pixels[i]   = UInt8(rTable[Int(pixels[i])] * 255)
            pixels[i+1] = UInt8(gTable[Int(pixels[i+1])] * 255)
            pixels[i+2] = UInt8(bTable[Int(pixels[i+2])] * 255)
            i += 4
        }
    }

    static func makeImage(from pixels: [UInt8]) -> NSImage? {
        let width = 128, height = 128
        var mutablePixels = pixels
        guard let ctx = CGContext(
            data: &mutablePixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ), let cgImg = ctx.makeImage() else { return nil }
        return NSImage(cgImage: cgImg, size: NSSize(width: width, height: height))
    }
}
