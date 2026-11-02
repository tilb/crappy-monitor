import AppKit
import CoreVideo

// LENS PROTOTYPE — throwaway.

/// Renders the strip tiles: a 1:1 crop (124 × 70 pt) of the captured screen,
/// run through each monitor's tables on the CPU. Same tables as the lens.
final class Thumbnailer {
    static let tileSize = CGSize(width: 124, height: 70)

    private let queue = DispatchQueue(label: "com.crappymonitor.lens.thumbs", qos: .userInitiated)
    private var lutCache: [LensParams: [[UInt8]]] = [:]   // only touched on `queue`
    private var busy = false                               // main thread

    /// - Parameter center: crop centre in global screen points.
    func render(frame: ScreenCapture.Frame,
                center: CGPoint,
                jobs: [(id: String, params: LensParams)],
                completion: @escaping ([String: NSImage]) -> Void) {
        guard !busy else { return }
        busy = true
        queue.async { [self] in
            let images = renderSync(frame: frame, center: center, jobs: jobs)
            DispatchQueue.main.async {
                self.busy = false
                completion(images)
            }
        }
    }

    private func renderSync(frame: ScreenCapture.Frame, center: CGPoint,
                            jobs: [(id: String, params: LensParams)]) -> [String: NSImage] {
        let buf = frame.buffer
        let ppp = frame.pixelsPerPoint
        let w = Int(Self.tileSize.width * ppp), h = Int(Self.tileSize.height * ppp)
        let bufW = CVPixelBufferGetWidth(buf), bufH = CVPixelBufferGetHeight(buf)
        guard w > 0, h > 0, w <= bufW, h <= bufH else { return [:] }

        let cx = Int((center.x - frame.displayFrame.minX) * ppp)
        let cy = Int((frame.displayFrame.maxY - center.y) * ppp)
        let x0 = min(max(cx - w / 2, 0), bufW - w)
        let y0 = min(max(cy - h / 2, 0), bufH - h)

        // Copy the crop out of the IOSurface (BGRA).
        var crop = [UInt8](repeating: 0, count: w * h * 4)
        CVPixelBufferLockBaseAddress(buf, .readOnly)
        if let base = CVPixelBufferGetBaseAddress(buf) {
            let rowBytes = CVPixelBufferGetBytesPerRow(buf)
            crop.withUnsafeMutableBytes { dst in
                for row in 0..<h {
                    let src = base + (y0 + row) * rowBytes + x0 * 4
                    memcpy(dst.baseAddress! + row * w * 4, src, w * 4)
                }
            }
        }
        CVPixelBufferUnlockBaseAddress(buf, .readOnly)

        var out: [String: NSImage] = [:]
        let block = max(1, Int(ppp.rounded()))
        // Non-retina source: every block holds the average of its pixels, like the lens.
        let averaged = (block > 1 && jobs.contains { $0.params.nonRetina })
            ? Self.blockAverage(crop, w, h, block: block, originX: x0, originY: y0) : crop
        for job in jobs {
            let luts = lut(for: job.params)
            let r = luts[0], g = luts[1], b = luts[2]
            let src = job.params.nonRetina ? averaged : crop
            var px = [UInt8](repeating: 255, count: w * h * 4)
            for i in stride(from: 0, to: w * h * 4, by: 4) {
                px[i] = b[Int(src[i])]
                px[i + 1] = g[Int(src[i + 1])]
                px[i + 2] = r[Int(src[i + 2])]
            }
            if let img = Self.makeImage(px, w, h) { out[job.id] = img }
        }
        return out
    }

    /// Averages each block × block cell (in approximately linear light) and fills
    /// the cell with that colour. The grid is aligned to the display, not the crop.
    private static func blockAverage(_ px: [UInt8], _ w: Int, _ h: Int, block: Int,
                                     originX: Int, originY: Int) -> [UInt8] {
        let toLinear = (0..<256).map { pow(Float($0) / 255, 2.2) }
        var out = px
        var by = -(originY % block)
        while by < h {
            var bx = -(originX % block)
            while bx < w {
                let ys = max(0, by)..<min(h, by + block), xs = max(0, bx)..<min(w, bx + block)
                var acc: (Float, Float, Float) = (0, 0, 0)
                for y in ys { for x in xs {
                    let i = (y * w + x) * 4
                    acc.0 += toLinear[Int(px[i])]; acc.1 += toLinear[Int(px[i + 1])]; acc.2 += toLinear[Int(px[i + 2])]
                } }
                let n = Float(ys.count * xs.count)
                let enc = { (v: Float) in UInt8((pow(v / n, 1 / 2.2) * 255).rounded().clamped(to: 0...255)) }
                let c = (enc(acc.0), enc(acc.1), enc(acc.2))
                for y in ys { for x in xs {
                    let i = (y * w + x) * 4
                    out[i] = c.0; out[i + 1] = c.1; out[i + 2] = c.2
                } }
                bx += block
            }
            by += block
        }
        return out
    }

    private func lut(for params: LensParams) -> [[UInt8]] {
        if let hit = lutCache[params] { return hit }
        let (r, g, b) = params.tables()
        let luts = [r, g, b].map { $0.map { UInt8(($0 * 255).rounded().clamped(to: 0...255)) } }
        if lutCache.count > 64 { lutCache.removeAll() }
        lutCache[params] = luts
        return luts
    }

    private static func makeImage(_ pixels: [UInt8], _ w: Int, _ h: Int) -> NSImage? {
        var data = pixels
        let info = CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: info),
              let cg = ctx.makeImage() else { return nil }
        return NSImage(cgImage: cg, size: tileSize)
    }
}
