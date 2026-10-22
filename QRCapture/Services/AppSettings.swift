import Foundation
import ServiceManagement

@MainActor
final class AppSettings: ObservableObject {
    @Published private(set) var shortcut: KeyboardShortcut
    @Published private(set) var launchAtLogin = false
    @Published private(set) var loginNeedsApproval = false
    private let defaults = UserDefaults.standard

    init() {
        if let data = defaults.data(forKey: "keyboardShortcut"),
           let stored = try? JSONDecoder().decode(KeyboardShortcut.self, from: data) {
            shortcut = stored
        } else {
            shortcut = .initial
        }
        refreshLoginStatus()
    }

    func saveShortcut(_ shortcut: KeyboardShortcut) {
        self.shortcut = shortcut
        defaults.set(try? JSONEncoder().encode(shortcut), forKey: "keyboardShortcut")
    }

    func refreshLoginStatus() {
        let status = SMAppService.mainApp.status
        launchAtLogin = status == .enabled || status == .requiresApproval
        loginNeedsApproval = status == .requiresApproval
    }

    func setLaunchAtLogin(_ enabled: Bool) throws {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            refreshLoginStatus()
            throw error
        }
        refreshLoginStatus()
    }
}
