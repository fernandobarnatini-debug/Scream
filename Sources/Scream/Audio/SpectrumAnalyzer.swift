import Accelerate

/// Real-time FFT of the 16 kHz mic feed, reduced to log-spaced frequency
/// bands for the waveform. Runs entirely on the audio tap thread — the
/// rolling buffer and scratch arrays are touched from nowhere else.
final class SpectrumAnalyzer {
    static let bandCount = 14
    private static let fftSize = 1024
    private static let halfSize = fftSize / 2

    private let setup: vDSP_DFT_Setup
    private let window: [Float]
    private let bandRanges: [Range<Int>]

    private var rolling: [Float] = []
    private var inReal = [Float](repeating: 0, count: SpectrumAnalyzer.halfSize)
    private var inImag = [Float](repeating: 0, count: SpectrumAnalyzer.halfSize)
    private var outReal = [Float](repeating: 0, count: SpectrumAnalyzer.halfSize)
    private var outImag = [Float](repeating: 0, count: SpectrumAnalyzer.halfSize)
    private var magnitudes = [Float](repeating: 0, count: SpectrumAnalyzer.halfSize)

    init?() {
        guard let setup = vDSP_DFT_zrop_CreateSetup(nil, vDSP_Length(Self.fftSize), .FORWARD) else {
            return nil
        }
        self.setup = setup
        window = vDSP.window(
            ofType: Float.self,
            usingSequence: .hanningDenormalized,
            count: Self.fftSize,
            isHalfWindow: false
        )

        // Log-spaced bands covering speech: 80 Hz … 6.4 kHz.
        let binWidth = AudioRecorder.targetSampleRate / Double(Self.fftSize)
        let minF = 80.0
        let maxF = 6400.0
        var ranges: [Range<Int>] = []
        var previousEdge = max(1, Int(minF / binWidth))
        for band in 1...Self.bandCount {
            let f = minF * pow(maxF / minF, Double(band) / Double(Self.bandCount))
            let edge = min(Self.halfSize - 1, max(previousEdge + 1, Int(f / binWidth)))
            ranges.append(previousEdge..<edge)
            previousEdge = edge
        }
        bandRanges = ranges
    }

    deinit {
        vDSP_DFT_DestroySetup(setup)
    }

    /// Feed converted samples; returns fresh 0…1 band energies once a full
    /// FFT window has accumulated.
    func analyze(appending samples: [Float]) -> [Float]? {
        rolling.append(contentsOf: samples)
        if rolling.count > Self.fftSize {
            rolling.removeFirst(rolling.count - Self.fftSize)
        }
        guard rolling.count == Self.fftSize else { return nil }

        var windowed = [Float](repeating: 0, count: Self.fftSize)
        vDSP.multiply(rolling, window, result: &windowed)

        // Pack even/odd reals into split-complex form for the zrop transform.
        windowed.withUnsafeBufferPointer { buffer in
            buffer.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: Self.halfSize) { complexPtr in
                inReal.withUnsafeMutableBufferPointer { real in
                    inImag.withUnsafeMutableBufferPointer { imag in
                        var split = DSPSplitComplex(realp: real.baseAddress!, imagp: imag.baseAddress!)
                        vDSP_ctoz(complexPtr, 2, &split, 1, vDSP_Length(Self.halfSize))
                    }
                }
            }
        }

        vDSP_DFT_Execute(setup, inReal, inImag, &outReal, &outImag)

        outReal.withUnsafeMutableBufferPointer { real in
            outImag.withUnsafeMutableBufferPointer { imag in
                var split = DSPSplitComplex(realp: real.baseAddress!, imagp: imag.baseAddress!)
                magnitudes.withUnsafeMutableBufferPointer { mags in
                    vDSP_zvabs(&split, 1, mags.baseAddress!, 1, vDSP_Length(Self.halfSize))
                }
            }
        }

        var bands = [Float](repeating: 0, count: Self.bandCount)
        magnitudes.withUnsafeBufferPointer { mags in
            for (index, range) in bandRanges.enumerated() {
                var mean: Float = 0
                vDSP_meamgv(mags.baseAddress! + range.lowerBound, 1, &mean, vDSP_Length(range.count))
                let db = 20 * log10(mean / Float(Self.fftSize) + 1e-9)
                bands[index] = min(1, max(0, (db + 58) / 40))
            }
        }
        return bands
    }
}
