import CoreGraphics
import Metal

/// Pure geometry for a lens that may span several displays (PRD §6, Vraag 9).
/// All rects are global Cocoa screen points (bottom-left origin).
enum LensLayout {

    /// One display as far as layout cares.
    struct Display: Equatable {
        var id: CGDirectDisplayID
        var frame: CGRect            // global points
        var pixelsPerPoint: CGFloat  // capture pixels per point
    }

    /// What one display contributes to a target.
    struct Placement: Equatable {
        var displayID: CGDirectDisplayID
        var region: RenderRegion
        /// The target pixels this display covers (top-left origin).
        var scissor: MTLScissorRect
        /// Non-retina block: capture pixels per display point.
        var block: Int

        static func == (a: Placement, b: Placement) -> Bool {
            a.displayID == b.displayID && a.region == b.region && a.block == b.block
                && a.scissor.x == b.scissor.x && a.scissor.y == b.scissor.y
                && a.scissor.width == b.scissor.width && a.scissor.height == b.scissor.height
        }
    }

    /// The displays `rect` overlaps, in the order given.
    static func displays(overlapping rect: CGRect,
                         in screens: [(id: CGDirectDisplayID, frame: CGRect)]) -> [CGDirectDisplayID] {
        screens.filter { $0.frame.intersects(rect) }.map(\.id)
    }

    /// Splits a target covering `rect` (drawn at `targetScale` pixels per point, `size`
    /// pixels) into one placement per display it overlaps. Placement edges are rounded
    /// the same way on both sides, so neighbouring displays tile the target exactly.
    static func placements(for rect: CGRect, targetScale: CGFloat, size: (width: Int, height: Int),
                           displays: [Display]) -> [Placement] {
        displays.compactMap { d in
            let part = rect.intersection(d.frame)
            guard !part.isNull, part.width > 0, part.height > 0 else { return nil }
            func px(_ v: CGFloat, _ limit: Int) -> Int { min(max(Int((v * targetScale).rounded()), 0), limit) }
            let x0 = px(part.minX - rect.minX, size.width), x1 = px(part.maxX - rect.minX, size.width)
            let y0 = px(rect.maxY - part.maxY, size.height), y1 = px(rect.maxY - part.minY, size.height)
            guard x1 > x0, y1 > y0 else { return nil }
            let ppp = d.pixelsPerPoint
            return Placement(
                displayID: d.id,
                region: RenderRegion(origin: SIMD2(Float((rect.minX - d.frame.minX) * ppp),
                                                   Float((d.frame.maxY - rect.maxY) * ppp)),
                                     scale: Float(ppp / targetScale)),
                scissor: MTLScissorRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0),
                block: max(1, Int(ppp.rounded())))
        }
    }
}
