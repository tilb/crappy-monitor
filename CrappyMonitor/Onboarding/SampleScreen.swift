import SwiftUI

/// A made-up screen of the kind our users' designers build: a pale, airy healthcare
/// dashboard with light grey text, hairlines and soft status colours. Exactly what
/// suffers on an office monitor, so the intro demo shows the point in one look.
/// Its colours are "user content", not app chrome, so they are fixed and always light.
struct SampleScreen: View {
    static let size = CGSize(width: 560, height: 315)

    private let page = Color(hex: 0xF9FAFB)
    private let sidebar = Color(hex: 0xF3F4F6)
    private let border = Color(hex: 0xE5E7EB)
    private let ink = Color(hex: 0x111827)
    private let muted = Color(hex: 0x9CA3AF)
    private let faint = Color(hex: 0xD1D5DB)
    private let accent = Color(hex: 0x3B82F6)
    private let accentWash = Color(hex: 0xE8F0FE)
    private let teal = Color(hex: 0x5EBFB8)

    var body: some View {
        HStack(spacing: 0) {
            side
            Rectangle().fill(border).frame(width: 1)
            main
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(page)
        .environment(\.colorScheme, .light)
    }

    private var side: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Circle().fill(teal).frame(width: 14, height: 14)
                Text("CareBoard").font(.system(size: 11, weight: .semibold)).foregroundStyle(ink)
            }
            .padding(.bottom, 12)
            nav("Overview", "square.grid.2x2", selected: true)
            nav("Patients", "person.2")
            nav("Rounds", "checklist")
            nav("Reports", "chart.bar")
            Spacer()
        }
        .padding(12)
        .frame(width: 118, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(sidebar)
    }

    private func nav(_ title: String, _ symbol: String, selected: Bool = false) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 9))
            Text(title).font(.system(size: 10, weight: selected ? .medium : .regular))
        }
        .foregroundStyle(selected ? accent : muted)
        .padding(.horizontal, 6).padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? accentWash : .clear, in: RoundedRectangle(cornerRadius: 5))
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ward 4B").font(.system(size: 15, weight: .semibold)).foregroundStyle(ink)
                    Text("Thursday · 14 patients · updated 2 min ago").font(.system(size: 9)).foregroundStyle(muted)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass").font(.system(size: 8))
                    Text("Search patients").font(.system(size: 9))
                }
                .foregroundStyle(faint)
                .padding(.horizontal, 7).padding(.vertical, 5)
                .frame(width: 112, alignment: .leading)
                .background(.white, in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(border, lineWidth: 0.5))
                Text("New note").font(.system(size: 9, weight: .medium)).foregroundStyle(accent)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(accentWash, in: RoundedRectangle(cornerRadius: 5))
            }

            HStack(spacing: 8) {
                stat("Heart rate", "72", "bpm", trend: [0.5, 0.55, 0.45, 0.6, 0.52, 0.58, 0.5, 0.62])
                stat("Blood pressure", "118/76", "mmHg", trend: [0.6, 0.58, 0.62, 0.55, 0.57, 0.5, 0.53, 0.5])
                stat("SpO₂", "97", "%", trend: [0.7, 0.72, 0.68, 0.7, 0.74, 0.71, 0.73, 0.75])
            }

            VStack(spacing: 0) {
                patient("M. de Vries", "Room 12 · admitted Mon", "Stable", Color(hex: 0x16A34A), Color(hex: 0xDCFCE7))
                Rectangle().fill(border).frame(height: 0.5)
                patient("A. Jansen", "Room 14 · admitted Tue", "Review", Color(hex: 0xD97706), Color(hex: 0xFEF3C7))
                Rectangle().fill(border).frame(height: 0.5)
                patient("L. Bakker", "Room 15 · admitted Wed", "Stable", Color(hex: 0x16A34A), Color(hex: 0xDCFCE7))
            }
            .background(.white, in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(border, lineWidth: 0.5))
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func stat(_ label: String, _ value: String, _ unit: String, trend: [CGFloat]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9)).foregroundStyle(muted)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.system(size: 17, weight: .light)).foregroundStyle(ink)
                Text(unit).font(.system(size: 8.5)).foregroundStyle(muted)
            }
            Sparkline(values: trend).stroke(teal, style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                .frame(height: 18)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(border, lineWidth: 0.5))
    }

    private func patient(_ name: String, _ detail: String, _ status: String, _ fg: Color, _ bg: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(Color(hex: 0xEEF2F7)).frame(width: 18, height: 18)
                .overlay(Text(String(name.split(separator: " ").last?.prefix(1) ?? "")).font(.system(size: 8, weight: .medium)).foregroundStyle(muted))
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.system(size: 10, weight: .medium)).foregroundStyle(ink)
                Text(detail).font(.system(size: 8.5)).foregroundStyle(muted)
            }
            Spacer()
            Text(status).font(.system(size: 8.5, weight: .medium)).foregroundStyle(fg)
                .padding(.horizontal, 7).padding(.vertical, 2.5)
                .background(bg, in: Capsule())
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
    }
}

private struct Sparkline: Shape {
    let values: [CGFloat]
    func path(in r: CGRect) -> Path {
        var p = Path()
        guard values.count > 1 else { return p }
        for (i, v) in values.enumerated() {
            let pt = CGPoint(x: r.minX + r.width * CGFloat(i) / CGFloat(values.count - 1), y: r.maxY - r.height * v)
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        return p
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
}
