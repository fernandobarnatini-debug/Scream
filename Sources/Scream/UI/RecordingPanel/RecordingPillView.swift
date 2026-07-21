import SwiftUI

struct RecordingPillView: View {
    var model: PanelDisplayModel
    var levelMonitor: AudioLevelMonitor
    @Environment(\.colorScheme) private var colorScheme

    /// Monochrome ink: white on dark, black on light.
    private var ink: Color {
        colorScheme == .dark ? .white : .black
    }

    var body: some View {
        HStack(spacing: 10) {
            switch model.display {
            case .recording:
                StrandWaveView(level: levelMonitor.level, bands: levelMonitor.bands, ink: ink)
            case .transcribing:
                ThinkingStrandView(ink: ink)
                Text("Transcribing…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(ink)
                    .shadow(color: ink.opacity(0.55), radius: 6)
            case .error(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text(message)
                    .font(.callout)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 40)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(ink.opacity(0.22), lineWidth: 1))
        .shadow(color: haloColor, radius: 9 + 14 * CGFloat(glowLevel), y: 2)
        .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.15), value: model.display)
    }

    private var glowLevel: Float {
        model.display == .recording ? levelMonitor.level : 0
    }

    private var haloColor: Color {
        colorScheme == .dark
            ? .white.opacity(0.10 + 0.38 * Double(glowLevel))
            : .black.opacity(0.12 + 0.20 * Double(glowLevel))
    }
}

/// The live voice visualizer: five flowing sine strands whose amplitudes are
/// driven by different slices of the real FFT spectrum — lows breathe through
/// the slow wide strand, sibilants ripple the fast tight ones. Monochrome,
/// with a soft bloom on the lead strand.
struct StrandWaveView: View {
    var level: Float
    var bands: [Float]
    var ink: Color

    private struct Strand {
        let frequency: Double   // sine cycles across the width
        let speed: Double       // phase velocity; sign = travel direction
        let amplitude: Double   // relative height share
        let lineWidth: CGFloat
        let opacity: Double
        let bandRange: Range<Int>
    }

    private static let strands: [Strand] = [
        Strand(frequency: 1.2, speed: 2.1, amplitude: 1.00, lineWidth: 2.2, opacity: 1.00, bandRange: 0..<5),
        Strand(frequency: 1.8, speed: -2.9, amplitude: 0.85, lineWidth: 1.5, opacity: 0.55, bandRange: 3..<8),
        Strand(frequency: 2.5, speed: 3.8, amplitude: 0.62, lineWidth: 1.2, opacity: 0.42, bandRange: 6..<11),
        Strand(frequency: 3.1, speed: -4.6, amplitude: 0.46, lineWidth: 1.0, opacity: 0.30, bandRange: 9..<14),
        Strand(frequency: 0.9, speed: 1.6, amplitude: 0.72, lineWidth: 1.4, opacity: 0.45, bandRange: 0..<3),
    ]

    private static let sampleSteps = 72

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                draw(in: ctx, size: size, time: time)
            }
        }
        .frame(width: 170, height: 30)
    }

    private func draw(in ctx: GraphicsContext, size: CGSize, time: Double) {
        // Hot gain curve: a normal speaking voice should visibly fill the pill.
        let boosted = min(1, pow(Double(level) * 1.7, 0.85))

        var paths: [(path: Path, strand: Strand, drive: Double)] = []
        for (index, strand) in Self.strands.enumerated() {
            let slice = bandEnergy(in: strand.bandRange)
            let drive = max(boosted * 0.55, min(1, slice * 2.1))
            let idle = 0.10 + 0.035 * sin(time * 1.3 + Double(index) * 1.9)
            // Slow per-strand amplitude LFO keeps the motion organic.
            let lfo = 0.85 + 0.15 * sin(time * (1.1 + 0.3 * Double(index)) + Double(index) * 2.1)
            let amplitude = max(idle, drive * strand.amplitude) * lfo * (Double(size.height) / 2 - 1.5)
            paths.append((
                strandPath(strand, index: index, amplitude: amplitude, size: size, time: time),
                strand,
                max(idle, drive)
            ))
        }

        // Bloom on the lead strand.
        if let lead = paths.first {
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 3))
                layer.stroke(
                    lead.path,
                    with: .color(ink.opacity(0.35 + 0.45 * lead.drive)),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
            }
        }

        // Faint strands first, lead strand last so it sits on top.
        for entry in paths.reversed() {
            ctx.stroke(
                entry.path,
                with: .color(ink.opacity(entry.strand.opacity)),
                style: StrokeStyle(lineWidth: entry.strand.lineWidth, lineCap: .round)
            )
        }
    }

    private func bandEnergy(in range: Range<Int>) -> Double {
        let clamped = range.clamped(to: bands.indices)
        guard !clamped.isEmpty else { return 0 }
        var total: Float = 0
        for index in clamped {
            total += bands[index]
        }
        return Double(total) / Double(clamped.count)
    }

    private func strandPath(
        _ strand: Strand,
        index: Int,
        amplitude: Double,
        size: CGSize,
        time: Double
    ) -> Path {
        let midY = size.height / 2
        var path = Path()
        for step in 0...Self.sampleSteps {
            let u = Double(step) / Double(Self.sampleSteps)
            let x = u * Double(size.width)
            // Bell envelope pins the strand ends to the midline.
            let envelope = pow(sin(.pi * u), 1.15)
            let phase = 2 * .pi * strand.frequency * u
                + time * strand.speed
                + Double(index) * 1.7
            let y = Double(midY) + envelope * amplitude * sin(phase)
            let point = CGPoint(x: x, y: y)
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}

/// Transcribing indicator: one quiet strand with a bright pulse sweeping
/// along it — continuity with the recording wave, monochrome.
struct ThinkingStrandView: View {
    var ink: Color

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let midY = size.height / 2
                var path = Path()
                let steps = 56
                for step in 0...steps {
                    let u = Double(step) / Double(steps)
                    let envelope = pow(sin(.pi * u), 1.1)
                    let amplitude = Double(size.height) * 0.26 * (1 + 0.18 * sin(time * 1.7))
                    let y = Double(midY) + envelope * amplitude * sin(2 * .pi * 1.7 * u + time * 2.3)
                    let point = CGPoint(x: u * Double(size.width), y: y)
                    if step == 0 {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }

                ctx.stroke(
                    path,
                    with: .color(ink.opacity(0.25)),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )

                // Sweeping highlight, wrapping around the end.
                let sweep = (time * 0.55).truncatingRemainder(dividingBy: 1)
                let segmentLength = 0.22
                let end = sweep + segmentLength
                var segments = [path.trimmedPath(from: sweep, to: min(1, end))]
                if end > 1 {
                    segments.append(path.trimmedPath(from: 0, to: end - 1))
                }
                for segment in segments {
                    ctx.drawLayer { layer in
                        layer.addFilter(.blur(radius: 2.5))
                        layer.stroke(
                            segment,
                            with: .color(ink.opacity(0.7)),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                    }
                    ctx.stroke(
                        segment,
                        with: .color(ink.opacity(0.95)),
                        style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
                    )
                }
            }
        }
        .frame(width: 92, height: 22)
    }
}
