import AppKit
import SwiftUI

@main
struct QRCaptureApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: AppController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        do {
            let controller = AppController(history: try HistoryStore())
            self.controller = controller
            controller.start()
        } catch {
            // Do not overwrite an unreadable history file with an empty history.
            let alert = NSAlert()
            alert.messageText = "Не удалось загрузить историю QR Capture"
            alert.informativeText = "История сохранена без изменений. \(error.localizedDescription)"
            alert.addButton(withTitle: "Закрыть приложение")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
