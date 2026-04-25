import Carbon.HIToolbox
import os

/// Registers global hotkeys using Carbon's RegisterEventHotKey API.
/// This is the standard approach even on modern macOS — there is no
/// SwiftUI/AppKit equivalent for global hotkeys.
///
/// Zero CPU usage — the OS delivers hotkey events via callback.
@MainActor
final class HotkeyService {
    struct Registration {
        let id: UInt32
        let hotKeyRef: EventHotKeyRef
        let handler: () -> Void
    }

    private var registrations: [UInt32: Registration] = [:]
    private var nextID: UInt32 = 1
    private var eventHandler: EventHandlerRef?
    private let logger = Logger(subsystem: "com.veil.app", category: "HotkeyService")

    init() {
        installCarbonHandler()
    }

    deinit {
        for reg in registrations.values {
            UnregisterEventHotKey(reg.hotKeyRef)
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }

    // MARK: - Public

    @discardableResult
    func register(_ combo: KeyCombination, handler: @escaping () -> Void) -> UInt32 {
        let id = nextID
        nextID += 1

        let hotKeyID = EventHotKeyID(signature: fourCharCode("Veil"), id: id)
        var hotKeyRef: EventHotKeyRef?

        let status = RegisterEventHotKey(
            combo.keyCode,
            combo.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let ref = hotKeyRef else {
            logger.error("Failed to register hotkey: \(status)")
            return 0
        }

        registrations[id] = Registration(id: id, hotKeyRef: ref, handler: handler)
        logger.debug("Registered hotkey \(combo.displayString) with id \(id)")
        return id
    }

    func unregister(_ id: UInt32) {
        guard let reg = registrations.removeValue(forKey: id) else { return }
        UnregisterEventHotKey(reg.hotKeyRef)
        logger.debug("Unregistered hotkey id \(id)")
    }

    func unregisterAll() {
        for reg in registrations.values {
            UnregisterEventHotKey(reg.hotKeyRef)
        }
        registrations.removeAll()
    }

    // MARK: - Carbon Event Handler

    private func installCarbonHandler() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // Store a pointer to self for the C callback
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let event = event, let userData = userData else { return OSStatus(eventNotHandledErr) }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr else { return status }

                let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    service.registrations[hotKeyID.id]?.handler()
                }

                return noErr
            },
            1,
            &eventSpec,
            selfPtr,
            &eventHandler
        )
    }
}

private func fourCharCode(_ string: String) -> OSType {
    var result: OSType = 0
    for char in string.utf8.prefix(4) {
        result = (result << 8) | OSType(char)
    }
    return result
}
