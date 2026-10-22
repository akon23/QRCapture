import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: AppController
    @ObservedObject var settings: AppSettings
    @State private var isRecording = false

    var body: some View {
        Form {
            Section("Сканирование области экрана") {
                HStack {
                    Text("Сочетание клавиш")
                    Spacer()
                    Button(isRecording ? "Нажмите сочетание…" : settings.shortcut.displayName) {
                        controller.beginShortcutRecording()
                        isRecording = true
                    }
                    .disabled(isRecording)
                }
                if isRecording {
                    Text("Удерживайте ⌘, ⌃ или ⌥ и нажмите клавишу. Esc — отмена.")
                        .font(.caption).foregroundStyle(.secondary)
                    ShortcutRecorder(
                        onShortcut: { shortcut in
                            isRecording = false
                            controller.changeShortcut(shortcut)
                        },
                        onCancel: {
                            isRecording = false
                            controller.cancelShortcutRecording()
                        }
                    )
                    .frame(height: 1)
                }
            }
            Section {
                Toggle("Запускать при входе в macOS", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { controller.setLaunchAtLogin($0) }
                ))
                if settings.loginNeedsApproval {
                    Button("Разрешить автозапуск в Системных настройках") {
                        SMAppService.openSystemSettingsLoginItems()
                    }
                }
            }
            Section {
                Text("История: последние 100 сканирований. Изображения не сохраняются.")
                Text("Распознавание и хранение выполняются на этом Mac. Сетевой доступ отключён.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 330)
        .onDisappear {
            isRecording = false
            controller.cancelShortcutRecording()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            if let window = notification.object as? NSWindow, window.title == "Настройки QR Capture" {
                isRecording = false
                controller.cancelShortcutRecording()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            isRecording = false
            controller.cancelShortcutRecording()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            settings.refreshLoginStatus()
        }
    }
}
