import SwiftUI

/// Renders the horizontal dot-to-bar waveform matching the dark HUD design.
/// Quiet audio renders as a crisp row of evenly spaced subtle grey dots; speech raises vertical capsule bars.
struct WaveformDotsView: View {
    let levels: [Float]
    let maxHeight: CGFloat

    init(levels: [Float], maxHeight: CGFloat = 46) {
        self.levels = levels
        self.maxHeight = maxHeight
    }

    var body: some View {
        GeometryReader { geometry in
            let count = max(1, levels.count)
            let dotWidth: CGFloat = 3
            let totalDotWidth = CGFloat(count) * dotWidth
            let spacing = max(2, (geometry.size.width - totalDotWidth) / CGFloat(max(1, count - 1)))

            HStack(alignment: .center, spacing: spacing) {
                ForEach(Array(levels.enumerated()), id: \.offset) { _, rawLevel in
                    let clamped = CGFloat(max(0, min(1, rawLevel)))
                    let barHeight = dotWidth + clamped * max(0, maxHeight - dotWidth)
                    let opacity = 0.36 + Double(clamped) * 0.56

                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(opacity))
                        .frame(width: dotWidth, height: barHeight)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: maxHeight)
        .animation(.linear(duration: 0.06), value: levels)
    }
}
