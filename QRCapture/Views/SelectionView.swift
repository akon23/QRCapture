import AppKit

final class CapturePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class SelectionView: NSView {
    private let image: CGImage
    private var startPoint: NSPoint?
    private var selectedRect = NSRect.zero
    var onSelect: ((CGImage) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    init(frame: NSRect, image: CGImage) {
        self.image = image
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { nil }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        let snapshot = NSImage(cgImage: image, size: bounds.size)
        snapshot.draw(in: bounds)
        NSColor.black.withAlphaComponent(0.38).setFill()
        bounds.fill()
        if !selectedRect.isEmpty {
            NSGraphicsContext.saveGraphicsState()
            selectedRect.clip()
            snapshot.draw(in: bounds)
            NSGraphicsContext.restoreGraphicsState()
            NSColor.white.setStroke()
            let border = NSBezierPath(rect: selectedRect.insetBy(dx: 0.5, dy: 0.5))
            border.lineWidth = 1
            border.stroke()
        }
        let help = "Выделите QR-код · Esc — отмена"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = help.size(withAttributes: attributes)
        let origin = NSPoint(x: (bounds.width - size.width) / 2, y: 64)
        let background = NSRect(x: origin.x - 16, y: origin.y - 10, width: size.width + 32, height: size.height + 20)
        NSColor.black.withAlphaComponent(0.8).setFill()
        NSBezierPath(roundedRect: background, xRadius: 10, yRadius: 10).fill()
        help.draw(at: origin, withAttributes: attributes)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        window?.makeFirstResponder(self)
        startPoint = convert(event.locationInWindow, from: nil)
        selectedRect = .zero
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        updateSelection(event)
    }

    override func mouseUp(with event: NSEvent) {
        updateSelection(event)
        guard selectedRect.width >= 3, selectedRect.height >= 3 else {
            onCancel?()
            return
        }
        // AppKit uses a bottom-left origin; CGImage cropping uses top-left pixels.
        let scaleX = CGFloat(image.width) / bounds.width
        let scaleY = CGFloat(image.height) / bounds.height
        let crop = CGRect(
            x: selectedRect.minX * scaleX,
            y: (bounds.height - selectedRect.maxY) * scaleY,
            width: selectedRect.width * scaleX,
            height: selectedRect.height * scaleY
        ).integral.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let croppedImage = image.cropping(to: crop) else {
            onCancel?()
            return
        }
        onSelect?(croppedImage)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel?() }
    }

    private func updateSelection(_ event: NSEvent) {
        guard let startPoint else { return }
        let point = convert(event.locationInWindow, from: nil)
        selectedRect = NSRect(
            x: min(startPoint.x, point.x),
            y: min(startPoint.y, point.y),
            width: abs(point.x - startPoint.x),
            height: abs(point.y - startPoint.y)
        ).intersection(bounds)
        needsDisplay = true
    }
}
