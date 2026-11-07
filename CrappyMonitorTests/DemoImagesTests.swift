import XCTest
@testable import CrappyMonitor

@MainActor
final class DemoImagesTests: XCTestCase {
    /// The intro's demo really runs through the filter: every age differs from the
    /// original, and older looks darker.
    func testDemoRendersEveryAgeThroughTheFilter() throws {
        let demo = DemoImages()
        let renderer = try XCTUnwrap(LensRenderer())
        demo.make(renderer: renderer, profile: try MonitorLibrary.bundled().firstRunDefault)
        let original = try XCTUnwrap(demo.original?.cgImage(forProposedRect: nil, context: nil, hints: nil))
        var means: [Double] = []
        for age in MonitorAge.allCases {
            let img = try XCTUnwrap(demo.aged[age]?.cgImage(forProposedRect: nil, context: nil, hints: nil), "\(age)")
            XCTAssertEqual(img.width, original.width)
            means.append(Self.mean(img))
            if let dir = ProcessInfo.processInfo.environment["DEMO_OUT"] {
                let rep = NSBitmapImageRep(cgImage: img)
                try rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(dir)/demo-\(age.rawValue).png"))
            }
        }
        XCTAssertLessThan(means.last!, means.first!, "10 years darker than new")
        XCTAssertNotEqual(means.first!, Self.mean(original), accuracy: 0.001)
    }

    private static func mean(_ img: CGImage) -> Double {
        let w = img.width, h = img.height
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        return Double(px.enumerated().filter { $0.offset % 4 != 3 }.reduce(0) { $0 + Int($1.element) }) / Double(w * h * 3) / 255
    }
}
