import AppKit
import Carbon

struct KeyboardShortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var keyLabel: String

    static let initial = KeyboardShortcut(
        keyCode: UInt32(kVK_ANSI_Q),
        modifiers: UInt32(controlKey | optionKey | cmdKey),
        keyLabel: "Q"
    )

    var displayName: String {
        var result = ""
        if modifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { result += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { result += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { result += "⌘" }
        return result + keyLabel
    }

    init(keyCode: UInt32, modifiers: UInt32, keyLabel: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyLabel = keyLabel
    }

    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.intersection([.command, .control, .option]).isEmpty,
              let characters = event.charactersIgnoringModifiers, !characters.isEmpty else { return nil }
        keyCode = UInt32(event.keyCode)
        var carbonFlags: UInt32 = 0
        if flags.contains(.command) { carbonFlags |= UInt32(cmdKey) }
        if flags.contains(.control) { carbonFlags |= UInt32(controlKey) }
        if flags.contains(.option) { carbonFlags |= UInt32(optionKey) }
        if flags.contains(.shift) { carbonFlags |= UInt32(shiftKey) }
        modifiers = carbonFlags
        switch Int(event.keyCode) {
        case kVK_Space: keyLabel = "Пробел"
        case kVK_Return: keyLabel = "↩"
        case kVK_Tab: keyLabel = "⇥"
        case kVK_Delete: keyLabel = "⌫"
        case kVK_LeftArrow: keyLabel = "←"
        case kVK_RightArrow: keyLabel = "→"
        case kVK_UpArrow: keyLabel = "↑"
        case kVK_DownArrow: keyLabel = "↓"
        default: keyLabel = characters.uppercased()
        }
    }
}
