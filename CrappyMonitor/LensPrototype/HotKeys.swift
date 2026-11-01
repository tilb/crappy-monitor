import Carbon.HIToolbox
import Foundation

// LENS PROTOTYPE — throwaway.

/// System-wide shortcuts (⌃⌘L / ⌃⌘W / ⌃⌘P) that work while another app is in
/// front, which matters in Follow Pointer mode and when the screen is degraded.
/// Carbon hot keys need no Accessibility permission, unlike a global key monitor.
final class HotKeys {
    private var refs: [EventHotKeyRef] = []
    private var actions: [UInt32: () -> Void] = [:]
    private var handler: EventHandlerRef?

    func register(_ keyCode: Int, modifiers: Int = cmdKey | controlKey, action: @escaping () -> Void) {
        if handler == nil { installHandler() }
        let id = UInt32(actions.count + 1)
        actions[id] = action
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x434D_4C4E), id: id)   // 'CMLN'
        if RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID,
                               GetApplicationEventTarget(), 0, &ref) == noErr, let ref {
            refs.append(ref)
        }
    }

    func unregisterAll() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
        actions.removeAll()
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }

    deinit { unregisterAll() }

    private func installHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let me = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            let hotKeys = Unmanaged<HotKeys>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { hotKeys.actions[hotKeyID.id]?() }
            return noErr
        }, 1, &spec, me, &handler)
    }
}
