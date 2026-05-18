import AppKit
import Combine
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var controlPanelWindow: NSWindow?

    private let filterSettings = FilterSettings()
    private let presetsStore = PresetsStore()
    private let gammaController = GammaController()
    private let displayModeController = DisplayModeController()
    private let pixelGridController = PixelGridController()
    private var settingsCancellable: AnyCancellable?
    private var pixelSimCancellable: AnyCancellable?

    // A/B compare — Option-key hold
    private var abGlobalMonitorToken: Any?
    private var abLocalMonitorToken: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        settingsCancellable = filterSettings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                // objectWillChange fires before the change; dispatch so we read the new value.
                // Skip while A/B compare is active.
                DispatchQueue.main.async { [weak self] in
                    guard let self, !self.filterSettings.isABActive else { return }
                    self.gammaController.apply(settings: self.filterSettings)
                }
            }

        filterSettings.lowResModeAvailable = displayModeController.isAvailable

        pixelSimCancellable = filterSettings.$pixelSimulation
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                guard let self else { return }
                if enabled {
                    let success = self.displayModeController.apply()
                    if !success {
                        // Mode switch failed (e.g. no low-res mode available). Reset
                        // the toggle so the UI reflects actual display state.
                        self.filterSettings.pixelSimulation = false
                        return
                    }
                    self.pixelGridController.apply()
                } else {
                    self.displayModeController.restore()
                    self.pixelGridController.remove()
                }
            }

        // Refresh lowResModeAvailable when the display configuration changes
        // (hotplug, clamshell open/close, sleep-wake).
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.filterSettings.lowResModeAvailable = self.displayModeController.isAvailable
            self.displayModeController.purgeStaleModes()
        }

        // Apply initial gamma state.
        gammaController.apply(settings: filterSettings)

        setupMenuBar()
        setupABToggle()

        // Restore any stale gamma from a prior crash.
        // Done last so it doesn't interfere with startup sequence.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            CGDisplayRestoreColorSyncSettings()
            self.gammaController.apply(settings: self.filterSettings)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let t = abGlobalMonitorToken { NSEvent.removeMonitor(t) }
        if let t = abLocalMonitorToken  { NSEvent.removeMonitor(t) }
        pixelGridController.remove()
        displayModeController.restore()
        gammaController.restore()
    }

    // MARK: - A/B Compare Toggle

    private func setupABToggle() {
        let handler: (NSEvent) -> Void = { [weak self] event in
            guard let self else { return }
            let wantsAB = event.modifierFlags.contains(.option)
            guard wantsAB != filterSettings.isABActive else { return }

            if wantsAB {
                filterSettings.isABActive = true
                gammaController.restore()
                pixelGridController.remove()
                statusItem?.button?.title = " ⌥MM"
            } else {
                filterSettings.isABActive = false
                gammaController.apply(settings: filterSettings)
                if filterSettings.pixelSimulation { pixelGridController.apply() }
                statusItem?.button?.title = " MM"
            }
        }

        abGlobalMonitorToken = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) {
            handler($0)
        }
        abLocalMonitorToken = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) {
            handler($0)
            return $0
        }
    }

    // MARK: - Menu bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "display.trianglebadge.exclamationmark",
                               accessibilityDescription: "MurkyMonitor")
        button.title = " MM"
        button.imagePosition = .imageLeft

        let menu = NSMenu()

        let presetsItem = NSMenuItem(title: "Presets", action: nil, keyEquivalent: "")
        let presetsMenu = NSMenu()
        for preset in presetsStore.presets {
            let item = NSMenuItem(title: preset.name,
                                  action: #selector(applyPreset(_:)),
                                  keyEquivalent: "")
            item.representedObject = preset
            item.target = self
            presetsMenu.addItem(item)
        }
        presetsItem.submenu = presetsMenu
        menu.addItem(presetsItem)

        menu.addItem(.separator())

        let hint = NSMenuItem(title: "Hold ⌥ to Compare", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Open Control Panel",
                     action: #selector(openControlPanel),
                     keyEquivalent: ",")
            .target = self
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit MurkyMonitor",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    // MARK: - Actions

    @objc private func applyPreset(_ sender: NSMenuItem) {
        guard let preset = sender.representedObject as? DegradationPreset else { return }
        preset.apply(to: filterSettings)
        gammaController.apply(settings: filterSettings)
    }

    @objc private func openControlPanel() {
        if let existing = controlPanelWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = ControlPanelView()
            .environmentObject(filterSettings)
            .environmentObject(presetsStore)

        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "MurkyMonitor — Control Panel"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 320, height: 480))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        controlPanelWindow = window
    }
}
