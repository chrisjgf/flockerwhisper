import Carbon.HIToolbox
import Foundation

/// Registers system-wide Carbon hotkeys without requiring Accessibility or Input Monitoring permissions.
/// - `Option + Space` is registered continuously while the app runs.
/// - `Escape` is registered dynamically only while the floating HUD is visible, so it never steals Esc from other apps.
@MainActor
public final class GlobalHotKeyManager {
    private static let signature: OSType = 0x464C_4B57 // 'FLKW'
    private static let toggleHotKeyID: UInt32 = 1
    private static let cancelHotKeyID: UInt32 = 2

    private var eventHandlerRef: EventHandlerRef?
    private var toggleHotKeyRef: EventHotKeyRef?
    private var cancelHotKeyRef: EventHotKeyRef?

    public var onToggle: (() -> Void)?
    public var onCancel: (() -> Void)?

    public init() {}

    deinit {
        if let ref = cancelHotKeyRef {
            UnregisterEventHotKey(ref)
        }
        if let ref = toggleHotKeyRef {
            UnregisterEventHotKey(ref)
        }
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
        }
    }

    @discardableResult
    public func registerToggleHotKey() -> Bool {
        installHandlerIfNeeded()

        if let existing = toggleHotKeyRef {
            UnregisterEventHotKey(existing)
            toggleHotKeyRef = nil
        }

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: Self.toggleHotKeyID)
        let status = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &toggleHotKeyRef
        )
        return status == noErr
    }

    public func setEscapeHotKeyEnabled(_ enabled: Bool) {
        if enabled {
            guard cancelHotKeyRef == nil else { return }
            installHandlerIfNeeded()
            let hotKeyID = EventHotKeyID(signature: Self.signature, id: Self.cancelHotKeyID)
            RegisterEventHotKey(
                UInt32(kVK_Escape),
                0,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &cancelHotKeyRef
            )
        } else if let existing = cancelHotKeyRef {
            UnregisterEventHotKey(existing)
            cancelHotKeyRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let userData = Unmanaged.passUnretained(self).toOpaque()
        let callback: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let event, let userData else { return noErr }
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
            guard status == noErr, hotKeyID.signature == GlobalHotKeyManager.signature else {
                return noErr
            }

            let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            let firedID = hotKeyID.id
            DispatchQueue.main.async {
                if firedID == GlobalHotKeyManager.toggleHotKeyID {
                    manager.onToggle?()
                } else if firedID == GlobalHotKeyManager.cancelHotKeyID {
                    manager.onCancel?()
                }
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventSpec,
            userData,
            &eventHandlerRef
        )
    }
}
