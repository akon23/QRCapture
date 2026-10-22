import Carbon
import Foundation

@MainActor
final class HotKeyService {
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    var onPress: (() -> Void)?

    init() {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, context in
                guard let context else { return OSStatus(eventNotHandledErr) }
                MainActor.assumeIsolated {
                    let service = Unmanaged<HotKeyService>.fromOpaque(context).takeUnretainedValue()
                    service.onPress?()
                }
                return noErr
            },
            1,
            &event,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    func register(_ shortcut: KeyboardShortcut) throws {
        guard eventHandler != nil else {
            throw NSError(
                domain: "QRCapture.HotKey",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Не удалось подключить обработчик горячей клавиши."]
            )
        }
        var replacement: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            EventHotKeyID(signature: 0x51524350, id: 1),
            GetApplicationEventTarget(),
            0,
            &replacement
        )
        guard status == noErr else {
            throw NSError(
                domain: "QRCapture.HotKey",
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "Не удалось назначить сочетание. Возможно, оно уже занято."]
            )
        }
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = replacement
    }

    func suspend() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
    }

    func stop() {
        suspend()
        if let eventHandler { RemoveEventHandler(eventHandler) }
        hotKey = nil
        eventHandler = nil
    }
}
