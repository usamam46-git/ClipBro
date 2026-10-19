import Carbon
import Foundation

@MainActor
final class HotkeyService {
    private var reference: EventHotKeyRef?
    private var registeredCode: UInt32?
    private var registeredModifiers: UInt32?
    private var handler: EventHandlerRef?
    var action: (() -> Void)?
    init() {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let service = Unmanaged<HotkeyService>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { service.action?() }
            return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    func register(code: UInt32, modifiers: UInt32) -> Bool {
        if registeredCode == code && registeredModifiers == modifiers { return true }
        var next: EventHotKeyRef?
        let status = RegisterEventHotKey(code, modifiers, EventHotKeyID(signature: 0x4342524F, id: 1), GetApplicationEventTarget(), 0, &next)
        guard status == noErr else { return false }
        if let reference { UnregisterEventHotKey(reference) }
        reference = next
        registeredCode = code; registeredModifiers = modifiers
        return true
    }
    // Used only by the isolated --ui-smoke-test --launcher-events harness.
    // Dispatches through Carbon's registered event handler, without synthesizing
    // global keystrokes or requiring Accessibility.
    func dispatchTestEvent() {
        guard ProcessInfo.processInfo.arguments.contains("--ui-smoke-test") else { return }
        var event: EventRef?
        guard CreateEvent(nil, OSType(kEventClassKeyboard), UInt32(kEventHotKeyPressed), 0, 0, &event) == noErr, let event else { return }
        defer { ReleaseEvent(event) }
        var identity = EventHotKeyID(signature: 0x4342524F, id: 1)
        SetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), MemoryLayout<EventHotKeyID>.size, &identity)
        SendEventToEventTarget(event, GetApplicationEventTarget())
    }
    func stop() {
        if let reference { UnregisterEventHotKey(reference) }
        if let handler { RemoveEventHandler(handler) }
        reference = nil; handler = nil; registeredCode = nil; registeredModifiers = nil
    }
}
