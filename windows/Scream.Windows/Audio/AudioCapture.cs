using System;
using NAudio.Wave;
using Scream.Windows.Support;

namespace Scream.Windows.Audio;

/// <summary>
/// Captures the microphone at 16 kHz mono 16-bit (via NAudio WaveInEvent) and exposes
/// the samples as Float32 for Whisper, plus a live RMS level for the pill visualizer.
/// </summary>
internal sealed class AudioCapture : IDisposable
{
    public const int SampleRate = 16000;
    private const int MaxSamples = SampleRate * 300; // 5-minute cap

    private readonly object _gate = new();
    private WaveInEvent? _waveIn;
    private float[] _buffer = new float[SampleRate * 8];
    private int _count;
    private volatile float _level;
    private bool _stopRequested;

    /// <summary>Most recent RMS level, 0..1. Safe to read from any thread.</summary>
    public float Level => _level;

    /// <summary>
    /// Opens the mic and begins capture. This is called off the UI thread (opening a
    /// device can be slow), so it cooperates with a concurrent Stop/Cancel via
    /// <c>_stopRequested</c>: if a stop lands before the device is published, the
    /// device is torn down immediately and nothing leaks.
    /// </summary>
    public void Start()
    {
        StopDevice();
        lock (_gate)
        {
            _count = 0;
            _level = 0f;
            _stopRequested = false;
        }

        var device = new WaveInEvent
        {
            WaveFormat = new WaveFormat(SampleRate, 16, 1),
            BufferMilliseconds = 50,
            NumberOfBuffers = 3,
        };
        device.DataAvailable += OnData;

        try
        {
            device.StartRecording();
        }
        catch
        {
            device.DataAvailable -= OnData;
            try { device.Dispose(); } catch { /* ignore */ }
            throw;
        }

        bool abort;
        lock (_gate)
        {
            abort = _stopRequested;
            if (!abort) _waveIn = device;
        }

        if (abort)
        {
            // Stop() ran before we published the device — tear it down now.
            device.DataAvailable -= OnData;
            try { device.StopRecording(); } catch { /* ignore */ }
            try { device.Dispose(); } catch { /* ignore */ }
            return;
        }

        Logger.Info("Microphone capture started");
    }

    /// <summary>Stops capture and returns the recorded Float32 samples.</summary>
    public float[] Stop()
    {
        lock (_gate) { _stopRequested = true; }
        StopDevice();
        lock (_gate)
        {
            var result = new float[Math.Min(_count, MaxSamples)];
            Array.Copy(_buffer, result, result.Length);
            _count = 0;
            _level = 0f;
            Logger.Info($"Microphone capture stopped ({result.Length} samples)");
            return result;
        }
    }

    public void Cancel()
    {
        lock (_gate) { _stopRequested = true; }
        StopDevice();
        lock (_gate)
        {
            _count = 0;
            _level = 0f;
        }
        Logger.Info("Microphone capture cancelled");
    }

    private void OnData(object? sender, WaveInEventArgs e)
    {
        int sampleCount = e.BytesRecorded / 2;
        double sumSq = 0;
        lock (_gate)
        {
            EnsureCapacity(_count + sampleCount);
            for (int i = 0; i < sampleCount; i++)
            {
                short s = (short)(e.Buffer[i * 2] | (e.Buffer[i * 2 + 1] << 8));
                float f = s / 32768f;
                if (_count < MaxSamples)
                    _buffer[_count++] = f;
                sumSq += (double)f * f;
            }
        }
        if (sampleCount > 0)
            _level = (float)Math.Sqrt(sumSq / sampleCount);
    }

    private void EnsureCapacity(int needed)
    {
        if (needed <= _buffer.Length) return;
        int newSize = _buffer.Length;
        int cap = MaxSamples + SampleRate;
        while (newSize < needed && newSize < cap) newSize *= 2;
        Array.Resize(ref _buffer, Math.Min(newSize, cap));
    }

    /// <summary>
    /// Snapshots and clears the device outside the lock, then stops/disposes it. Doing
    /// this without holding _gate avoids deadlocking against an in-flight OnData callback.
    /// </summary>
    private void StopDevice()
    {
        WaveInEvent? device;
        lock (_gate)
        {
            device = _waveIn;
            _waveIn = null;
        }
        if (device != null)
        {
            device.DataAvailable -= OnData;
            try { device.StopRecording(); } catch { /* ignore */ }
            try { device.Dispose(); } catch { /* ignore */ }
        }
    }

    public void Dispose() => StopDevice();
}
