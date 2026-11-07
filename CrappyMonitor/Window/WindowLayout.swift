import CoreGraphics

/// The lens window's layout rules in one place (PRD §5.4, review 2 Vraag 18):
/// - The green button zooms to fill the visible area of the display and back; never
///   native full screen.
/// - While zoomed the strip collapses to the footer automatically. A manual ⌥⌘S choice
///   made while zoomed holds until the window is un-zoomed.
/// - Collapsing is not shrinking: only collapsing by hand while not zoomed shrinks the
///   window to the compact size, and showing the strip again restores the earlier size.
/// - Un-zooming restores the frame and strip state from before the zoom. Moving or
///   resizing a zoomed window by hand ends the zoom where it is.
/// Pure value; the window controller applies the frames it returns.
struct WindowLayout: Equatable {
    static let compactSize = CGSize(width: 440, height: 330)

    private(set) var zoomed = false
    private(set) var collapsedByHand = false     // ⌥⌘S while not zoomed
    private(set) var zoomCollapsed: Bool?        // ⌥⌘S while zoomed; nil = automatic (collapsed)
    private(set) var restoreFrame: CGRect?       // before the zoom
    private(set) var expandedFrame: CGRect?      // before shrinking to the compact size

    /// Whether the strip shows as the collapsed footer.
    var stripCollapsed: Bool { zoomed ? (zoomCollapsed ?? true) : collapsedByHand }

    /// ⌥⌘S, the toolbar button or "Show Strip". Returns a new window frame, if any.
    mutating func toggleStrip(current: CGRect) -> CGRect? {
        if zoomed {
            zoomCollapsed = !stripCollapsed
            return nil
        }
        if collapsedByHand {
            collapsedByHand = false
            let size = expandedFrame?.size ?? current.size
            expandedFrame = nil
            return Self.anchoredTopLeft(current, size: size)
        } else {
            collapsedByHand = true
            expandedFrame = current
            return Self.anchoredTopLeft(current, size: Self.compactSize)
        }
    }

    /// The green button or Window › Zoom: fill `visible`, or go back.
    mutating func toggleZoom(current: CGRect, visible: CGRect) -> CGRect? {
        if zoomed {
            zoomed = false
            zoomCollapsed = nil
            defer { restoreFrame = nil }
            return restoreFrame
        }
        zoomed = true
        zoomCollapsed = nil
        restoreFrame = current
        return visible
    }

    /// The user moved or resized the window. A zoomed window that no longer fills
    /// `visible` is not zoomed any more; it keeps its frame.
    mutating func userChangedFrame(_ frame: CGRect, visible: CGRect) {
        guard zoomed, !Self.same(frame, visible) else { return }
        zoomed = false
        zoomCollapsed = nil
        restoreFrame = nil
    }

    static func anchoredTopLeft(_ f: CGRect, size: CGSize) -> CGRect {
        CGRect(x: f.minX, y: f.maxY - size.height, width: size.width, height: size.height)
    }

    private static func same(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) < 1 && abs(a.minY - b.minY) < 1 && abs(a.width - b.width) < 1 && abs(a.height - b.height) < 1
    }
}
