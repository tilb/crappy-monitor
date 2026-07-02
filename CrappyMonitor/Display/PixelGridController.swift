import AppKit
import CoreGraphics

class PixelGridController {
    private var overlayWindows: [NSWindow] = []

    func apply() {
        remove()
        for screen in NSScreen.screens {
            guard screen.backingScaleFactor > 1 else { continue } // alleen Retina
            let window = makeOverlay(for: screen)
            overlayWindows.append(window)
            window.orderFrontRegardless()
        }
    }

    func remove() {
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()
    }

    private func makeOverlay(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        window.backgroundColor = .clear
        window.isOpaque = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.contentView = PixelGridView(scaleFactor: screen.backingScaleFactor)
        return window
    }
}

private class PixelGridView: NSView {
    private let scaleFactor: CGFloat

    init(scaleFactor: CGFloat) {
        self.scaleFactor = scaleFactor
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // Raster-stap in logische punten = 1 simulated pixel = scaleFactor fysieke pixels
        let step: CGFloat = max(2.0, scaleFactor)
        let lineWidth: CGFloat = 1.0 / scaleFactor   // 1 fysieke pixel
        ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.18).cgColor)
        ctx.setLineWidth(lineWidth)
        // Verticale lijnen
        var x: CGFloat = 0
        while x <= bounds.width {
            ctx.move(to: CGPoint(x: x, y: 0))
            ctx.addLine(to: CGPoint(x: x, y: bounds.height))
            x += step
        }
        // Horizontale lijnen
        var y: CGFloat = 0
        while y <= bounds.height {
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: bounds.width, y: y))
            y += step
        }
        ctx.strokePath()
    }
}
