import Foundation
import Observation

/// Receives raw RMS + spectrum data from the audio thread and publishes
/// smoothed values for the waveform UI: an overall 0…1 level plus per-band
/// energies with fast attack / slow decay so speech feels punchy.
@MainActor
@Observable
final class AudioLevelMonitor {
    private(set) var level: Float = 0
    private(set) var bands: [Float] = Array(repeating: 0, count: SpectrumAnalyzer.bandCount)

    nonisolated init() {}

    nonisolated func push(rms: Float, bands newBands: [Float]?) {
        // Map -50 dB…0 dB onto 0…1.
        let db = 20 * log10(max(rms, .leastNonzeroMagnitude))
        let normalized = min(1, max(0, (db + 50) / 50))
        Task { @MainActor in
            self.update(level: normalized, newBands: newBands)
        }
    }

    func reset() {
        level = 0
        bands = Array(repeating: 0, count: SpectrumAnalyzer.bandCount)
    }

    private func update(level newLevel: Float, newBands: [Float]?) {
        // Fast attack, slow decay reads naturally for speech.
        level = newLevel > level ? newLevel : level * 0.7 + newLevel * 0.3

        if let newBands, newBands.count == bands.count {
            for index in bands.indices {
                let incoming = newBands[index]
                bands[index] = incoming > bands[index]
                    ? bands[index] * 0.25 + incoming * 0.75
                    : bands[index] * 0.80 + incoming * 0.20
            }
        } else {
            for index in bands.indices {
                bands[index] *= 0.85
            }
        }
    }
}
