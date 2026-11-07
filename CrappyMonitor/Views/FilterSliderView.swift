import SwiftUI

struct FilterSliderView: View {
    let label: String
    let range: ClosedRange<Double>
    @Binding var value: Double
    let format: String
    var scale: Double = 1     // display only, e.g. 100 to show 0…1 as a percentage

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: format, value * scale))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.primary)
            }
            Slider(value: $value, in: range)
        }
    }
}
