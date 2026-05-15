import CoreGraphics

class DisplayModeController {
    private var savedModes: [CGDirectDisplayID: CGDisplayMode] = [:]

    var isAvailable: Bool {
        activeDisplays().contains { hasLowResMode(for: $0) }
    }

    func apply() {
        let opts = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary
        var config: CGDisplayConfigRef?
        CGBeginDisplayConfiguration(&config)
        for display in activeDisplays() {
            guard let current = CGDisplayCopyDisplayMode(display),
                  let all = CGDisplayCopyAllDisplayModes(display, opts) as? [CGDisplayMode],
                  let target = all
                      .filter({ $0.isUsableForDesktopGUI() && $0.pixelWidth == $0.width && $0.width < current.width })
                      .max(by: { $0.width < $1.width })
            else { continue }
            savedModes[display] = current
            CGConfigureDisplayWithDisplayMode(config, display, target, nil)
        }
        CGCompleteDisplayConfiguration(config, .forAppOnly)
    }

    func restore() {
        guard !savedModes.isEmpty else { return }
        var config: CGDisplayConfigRef?
        CGBeginDisplayConfiguration(&config)
        for (display, mode) in savedModes {
            CGConfigureDisplayWithDisplayMode(config, display, mode, nil)
        }
        CGCompleteDisplayConfiguration(config, .forAppOnly)
        savedModes.removeAll()
    }

    private func hasLowResMode(for display: CGDirectDisplayID) -> Bool {
        let opts = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary
        guard let current = CGDisplayCopyDisplayMode(display),
              let all = CGDisplayCopyAllDisplayModes(display, opts) as? [CGDisplayMode] else { return false }
        return all.contains { $0.isUsableForDesktopGUI() && $0.pixelWidth == $0.width && $0.width < current.width }
    }

    // Remove stale display IDs that are no longer active (hotplug / sleep-wake).
    func purgeStaleModes() {
        let active = Set(activeDisplays())
        savedModes = savedModes.filter { active.contains($0.key) }
    }

    private func activeDisplays() -> [CGDirectDisplayID] {
        var ids = [CGDirectDisplayID](repeating: 0, count: 8)
        var count: UInt32 = 0
        CGGetActiveDisplayList(8, &ids, &count)
        return Array(ids.prefix(Int(count)))
    }
}
