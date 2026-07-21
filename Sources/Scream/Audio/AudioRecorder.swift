import AVFoundation
import Accelerate

/// Captures microphone audio and delivers it as 16 kHz mono Float32 samples,
/// the format WhisperKit consumes. The engine is kept warm between utterances
/// for instant starts; `stopEngine` is called by the idle timer to release the
/// mic (and the orange indicator dot).
///
/// Thread-safety: the AVAudioEngine tap fires on an audio thread; the sample
/// buffer is guarded by a lock, and all mutating entry points are cheap.
final class AudioRecorder: @unchecked Sendable {
    static let targetSampleRate: Double = 16_000
    private static let maxSamples = Int(targetSampleRate) * 300 // 5 min cap

    let levelMonitor = AudioLevelMonitor()

    private let engine = AVAudioEngine()
    // Touched only from the audio tap thread.
    private let analyzer = SpectrumAnalyzer()
    private let lock = NSLock()
    private var samples: [Float] = []
    private var capturing = false
    private var converter: AVAudioConverter?
    private var outputFormat: AVAudioFormat?

    var isEngineRunning: Bool { engine.isRunning }

    func startEngine() throws {
        guard !engine.isRunning else { return }
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw ScreamError.audioEngineUnavailable
        }
        guard
            let outFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: Self.targetSampleRate,
                channels: 1,
                interleaved: false
            ),
            let converter = AVAudioConverter(from: inputFormat, to: outFormat)
        else {
            throw ScreamError.audioEngineUnavailable
        }
        self.converter = converter
        self.outputFormat = outFormat

        input.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
            self?.process(buffer)
        }
        engine.prepare()
        try engine.start()
        Log.audio.info("Audio engine started at \(inputFormat.sampleRate, privacy: .public) Hz")
    }

    func stopEngine() {
        guard engine.isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        converter = nil
        outputFormat = nil
        Log.audio.info("Audio engine stopped")
    }

    func beginCapture() {
        lock.lock()
        samples.removeAll(keepingCapacity: true)
        capturing = true
        lock.unlock()
    }

    func endCapture() -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        capturing = false
        let captured = samples
        samples = []
        return captured
    }

    func cancelCapture() {
        lock.lock()
        capturing = false
        samples = []
        lock.unlock()
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
        guard let converter, let outputFormat else { return }
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 16
        guard let out = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return }

        var fed = false
        var error: NSError?
        let status = converter.convert(to: out, error: &error) { _, outStatus in
            if fed {
                outStatus.pointee = .noDataNow
                return nil
            }
            fed = true
            outStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, out.frameLength > 0, let channel = out.floatChannelData?[0] else { return }

        let frames = Int(out.frameLength)
        let chunk = Array(UnsafeBufferPointer(start: channel, count: frames))
        var rms: Float = 0
        vDSP_rmsqv(chunk, 1, &rms, vDSP_Length(frames))
        levelMonitor.push(rms: rms, bands: analyzer?.analyze(appending: chunk))

        lock.lock()
        if capturing, samples.count < Self.maxSamples {
            samples.append(contentsOf: chunk)
        }
        lock.unlock()
    }
}
