import AppKit
@preconcurrency import ScreenCaptureKit

@MainActor
final class CaptureService {
    private var panels: [CapturePanel] = []
    private var completion: ((CGImage?) -> Void)?
    private var previousApplication: NSRunningApplication?
    private var escapeMonitor: Any?

    func selectRegion() async throws -> CGImage? {
        guard CGPreflightScreenCaptureAccess() else {
            CGRequestScreenCaptureAccess()
            throw NSError(
                domain: "QRCapture.ScreenPermission",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey:
                    "Разрешите QR Capture запись экрана в Системных настройках → Конфиденциальность и безопасность → Запись экрана и системного аудио. Затем повторите сканирование; macOS может попросить перезапустить приложение."]
            )
        }
        previousApplication = NSWorkspace.shared.frontmostApplication
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        var snapshots: [(NSScreen, CGImage)] = []
        // Capture before showing any overlays so they never appear inside the scanned image.
        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                  let display = content.displays.first(where: { $0.displayID == number.uint32Value }) else { continue }
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = Int(screen.frame.width * screen.backingScaleFactor)
            configuration.height = Int(screen.frame.height * screen.backingScaleFactor)
            configuration.showsCursor = false
            configuration.captureResolution = .best
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            snapshots.append((screen, image))
        }
        guard !snapshots.isEmpty else { return nil }
        return await withCheckedContinuation { continuation in
            completion = { continuation.resume(returning: $0) }
            for (screen, image) in snapshots {
                let panel = CapturePanel(
                    contentRect: screen.frame,
                    styleMask: [.borderless],
                    backing: .buffered,
                    defer: false
                )
                panel.level = .screenSaver
                panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
                panel.isOpaque = true
                panel.backgroundColor = .black
                panel.isReleasedWhenClosed = false
                panel.hidesOnDeactivate = false
                let view = SelectionView(frame: NSRect(origin: .zero, size: screen.frame.size), image: image)
                view.onSelect = { [weak self] image in self?.finish(image) }
                view.onCancel = { [weak self] in self?.finish(nil) }
                panel.contentView = view
                panel.setFrame(screen.frame, display: false)
                panels.append(panel)
                panel.orderFrontRegardless()
            }
            NSApp.activate(ignoringOtherApps: true)
            let target = panels.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? panels.first
            target?.makeKeyAndOrderFront(nil)
            target?.makeFirstResponder(target?.contentView)
            escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == 53 {
                    self?.finish(nil)
                    return nil
                }
                return event
            }
        }
    }

    private func finish(_ image: CGImage?) {
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        escapeMonitor = nil
        for panel in panels {
            if let view = panel.contentView as? SelectionView {
                view.onSelect = nil
                view.onCancel = nil
            }
            panel.orderOut(nil)
            panel.contentView = nil
            panel.close()
        }
        panels.removeAll()
        previousApplication?.activate()
        previousApplication = nil
        let callback = completion
        completion = nil
        callback?(image)
    }
}
