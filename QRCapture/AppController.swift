import AppKit
import SwiftUI

@MainActor
final class AppController: NSObject, ObservableObject {
    let history: HistoryStore
    let settings = AppSettings()
    @Published private(set) var isBusy = false
    @Published private(set) var feedback: String?
    private let decoder = QRDecoder()
    private let capture = CaptureService()
    private let hotKey = HotKeyService()
    private var historyItem: NSStatusItem?
    private var scanItem: NSStatusItem?
    private var historyWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var feedbackTask: Task<Void, Never>?
    private var feedbackID = UUID()
    private var isRecordingShortcut = false

    init(history: HistoryStore) {
        self.history = history
        super.init()
    }

    func start() {
        historyItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = historyItem?.button {
            button.image = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: "История QR Capture")
            button.toolTip = "QR Capture — история"
            button.target = self
            button.action = #selector(toggleHistory)
        }
        scanItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateScanIcon()
        scanItem?.button?.target = self
        scanItem?.button?.action = #selector(startScan)
        hotKey.onPress = { [weak self] in self?.scanScreen() }
        do { try hotKey.register(settings.shortcut) }
        catch { showError(error) }
    }

    func stop() {
        hotKey.stop()
        feedbackTask?.cancel()
    }

    @objc private func toggleHistory() {
        if let historyWindow, historyWindow.isVisible {
            historyWindow.orderOut(nil)
            return
        }
        if historyWindow == nil {
            historyWindow = makeWindow(
                title: "QR Capture — история",
                size: NSSize(width: 590, height: 620),
                content: HistoryView(controller: self, history: history)
            )
            historyWindow?.minSize = NSSize(width: 460, height: 420)
        }
        NSApp.activate(ignoringOtherApps: true)
        historyWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func startScan() { scanScreen() }

    func scanScreen() {
        guard !isBusy, !isRecordingShortcut else { return }
        isBusy = true
        historyWindow?.orderOut(nil)
        settingsWindow?.orderOut(nil)
        Task {
            defer { isBusy = false }
            do {
                if let image = try await capture.selectRegion() {
                    try await process(image)
                }
            } catch { showError(error) }
        }
    }

    func scanClipboard() {
        guard !isBusy else { return }
        let pasteboard = NSPasteboard.general
        guard let images = pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage],
              let image = images.first,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            do { try await process(cgImage) }
            catch { showError(error) }
        }
    }

    private func process(_ image: CGImage) async throws {
        guard let text = try await decoder.decode(image) else { return }
        // Persist first: a storage failure must not silently discard the scan from history.
        try history.append(text)
        copy(text)
    }

    func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        showCopiedFeedback()
    }

    func remove(_ record: ScanRecord) {
        do { try history.remove(record) }
        catch { showError(error) }
    }

    func clearHistory() {
        do { try history.clear() }
        catch { showError(error) }
    }

    func showSettings() {
        settings.refreshLoginStatus()
        if settingsWindow == nil {
            settingsWindow = makeWindow(
                title: "Настройки QR Capture",
                size: NSSize(width: 480, height: 330),
                content: SettingsView(controller: self, settings: settings)
            )
            settingsWindow?.styleMask.remove(.resizable)
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func beginShortcutRecording() {
        isRecordingShortcut = true
        hotKey.suspend()
    }

    func cancelShortcutRecording() {
        guard isRecordingShortcut else { return }
        isRecordingShortcut = false
        do { try hotKey.register(settings.shortcut) }
        catch { showError(error) }
    }

    func changeShortcut(_ shortcut: KeyboardShortcut) {
        isRecordingShortcut = false
        do {
            try hotKey.register(shortcut)
            settings.saveShortcut(shortcut)
            updateScanIcon()
        } catch {
            let registrationError = error
            do { try hotKey.register(settings.shortcut) }
            catch { showError(error) }
            showError(registrationError)
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do { try settings.setLaunchAtLogin(enabled) }
        catch { showError(error) }
    }

    func showError(_ error: Error) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "QR Capture"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Понятно")
        alert.runModal()
    }

    private func updateScanIcon() {
        scanItem?.button?.image = NSImage(systemSymbolName: "qrcode.viewfinder", accessibilityDescription: "Сканировать код")
        scanItem?.button?.toolTip = "Сканировать код — \(settings.shortcut.displayName)"
    }

    private func showCopiedFeedback() {
        feedbackTask?.cancel()
        feedback = "Скопировано"
        scanItem?.button?.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: "Скопировано")
        let id = UUID()
        feedbackID = id
        feedbackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, let self, self.feedbackID == id else { return }
            self.feedback = nil
            self.updateScanIcon()
        }
    }

    private func makeWindow<Content: View>(title: String, size: NSSize, content: Content) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentView = NSHostingView(rootView: content)
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
