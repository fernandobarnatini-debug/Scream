using System;
using System.Diagnostics;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using Scream.Windows.Audio;
using Scream.Windows.Hotkeys;
using Scream.Windows.Insertion;
using Scream.Windows.Settings;
using Scream.Windows.Support;
using Scream.Windows.Transcription;
using Scream.Windows.UI;

namespace Scream.Windows.App;

/// <summary>
/// The orchestrator: hotkey commands in, inserted text out.
/// idle -> recording -> processing -> idle.
/// </summary>
internal sealed class AppController : IDisposable
{
    private enum SessionState { Idle, Recording, Processing }

    private readonly AppSettings _settings;
    private readonly AudioCapture _audio = new();
    private readonly WhisperService _whisper = new();
    private readonly KeyboardHook _hook = new();
    private readonly HotkeyManager _hotkeys;
    private readonly TextInserter _inserter;
    private readonly PillForm _pill;
    private readonly SynchronizationContext _sync;

    private SessionState _state = SessionState.Idle;

    public WhisperService Whisper => _whisper;
    public AppSettings Settings => _settings;

    /// <summary>Set by the tray to surface balloon notifications.</summary>
    public Action<string, string>? Balloon;

    public AppController()
    {
        _settings = AppSettings.Load();
        _hotkeys = new HotkeyManager(() => _settings);
        _inserter = new TextInserter(() => _settings);

        _pill = new PillForm(_audio);
        _ = _pill.Handle;      // create the handle on the UI thread up front
        _pill.Visible = false;

        _sync = SynchronizationContext.Current ?? new WindowsFormsSynchronizationContext();

        _hook.OnKey = e => _hotkeys.Handle(e);
        // The hook callback runs on the UI thread; defer the real work so the
        // callback returns immediately (LL hooks must not block).
        _hotkeys.OnCommand = cmd => Post(() => Dispatch(cmd));
    }

    private ModelInfo CurrentModelInfo => ModelCatalog.Find(_settings.Model) ?? ModelCatalog.Default;

    public bool CurrentModelDownloaded => ModelDownloader.IsDownloaded(CurrentModelInfo);

    public void Post(Action action) => _sync.Post(_ =>
    {
        try { action(); }
        catch (Exception ex) { Logger.Error("UI action failed", ex); }
    }, null);

    public void Start()
    {
        if (!_hook.Install())
            ShowBalloon("Keyboard hotkeys unavailable",
                "Scream could not register its keyboard hook. Try restarting the app.");

        var model = CurrentModelInfo;
        if (ModelDownloader.IsDownloaded(model))
            _ = LoadInitialModelAsync(model);
        else
            Logger.Info($"Selected model '{model.Name}' not downloaded yet");
    }

    private async Task LoadInitialModelAsync(ModelInfo model)
    {
        try
        {
            await _whisper.LoadModelAsync(model, ModelDownloader.LocalPath(model));
        }
        catch (Exception ex)
        {
            Logger.Error("Failed to load model at startup", ex);
            _whisper.SetError(ex.Message);
        }
    }

    /// <summary>Downloads (if needed) and loads a model, reporting download progress.</summary>
    public async Task ActivateModelAsync(ModelInfo model, IProgress<double>? downloadProgress, CancellationToken ct)
    {
        try
        {
            if (!ModelDownloader.IsDownloaded(model))
            {
                var progress = new Progress<double>(f =>
                {
                    _whisper.SetDownloading(model.DisplayName, f);
                    downloadProgress?.Report(f);
                });
                await ModelDownloader.DownloadAsync(model, progress, ct);
            }

            await _whisper.LoadModelAsync(model, ModelDownloader.LocalPath(model));
            _settings.Model = model.Name;
            _settings.Save();
        }
        catch (OperationCanceledException)
        {
            _whisper.SetError("download cancelled");
            throw;
        }
        catch (Exception ex)
        {
            Logger.Error("Model activation failed", ex);
            _whisper.SetError(ex.Message);
            throw;
        }
    }

    public void OnHotkeysChanged()
    {
        _hotkeys.Reset();
        Logger.Info($"Hotkeys changed: hold={_settings.HoldKey}, toggle={_settings.ToggleKey}");
    }

    public void SetStartup(bool enabled)
    {
        StartupManager.Set(enabled);
        _settings.StartWithWindows = enabled;
        _settings.Save();
    }

    // ---- Session state machine ----

    private void Dispatch(DictationCommand command)
    {
        switch (command)
        {
            case DictationCommand.BeginHold: BeginRecording("hold"); break;
            case DictationCommand.BeginToggle: BeginRecording("toggle"); break;
            case DictationCommand.EndHold:
            case DictationCommand.EndToggle: FinishRecording(); break;
            case DictationCommand.CancelHold:
            case DictationCommand.CancelActive: CancelRecording(); break;
        }
    }

    private void BeginRecording(string mode)
    {
        if (_state != SessionState.Idle) return;

        if (!_whisper.IsReady)
        {
            Logger.Warn("Begin recording ignored: model not ready");
            ShowBalloon("Scream", "No speech model is loaded yet. Open Settings to download one.");
            return;
        }

        _state = SessionState.Recording;
        _pill.ShowListening();
        Logger.Info($"Recording started ({mode})");

        // Open the mic off the UI thread: a slow device open must not stall the
        // low-level keyboard hook, which is pumped on the UI thread (Windows silently
        // drops the hook if a callback is starved). AudioCapture is race-safe against
        // a Stop() that lands before the device finishes opening.
        _ = Task.Run(() =>
        {
            try
            {
                _audio.Start();
            }
            catch (Exception ex)
            {
                Logger.Error("Failed to start microphone", ex);
                Post(() =>
                {
                    if (_state == SessionState.Recording)
                    {
                        EndSession();
                        ShowBalloon("Microphone problem",
                            "Scream couldn't start your microphone. Make sure one is connected and allowed.");
                    }
                });
            }
        });
    }

    private async void FinishRecording()
    {
        if (_state != SessionState.Recording) return;
        _state = SessionState.Processing;

        var samples = _audio.Stop();

        // Guards against empty/near-empty captures (e.g. a very fast release, or the
        // mic having been aborted mid-open) before handing anything to Whisper.
        if (samples.Length < AudioCapture.SampleRate / 4)
        {
            Logger.Info($"Recording too short ({samples.Length} samples); skipping");
            EndSession();
            ShowBalloon("Scream", "That was too quick — hold the key a moment longer while you speak.");
            return;
        }

        _pill.ShowTranscribing();

        var sw = Stopwatch.StartNew();
        string text;
        try
        {
            text = await Task.Run(() => _whisper.TranscribeAsync(samples));
        }
        catch (Exception ex)
        {
            Logger.Error("Transcription failed", ex);
            EndSession();
            ShowBalloon("Transcription failed", ex.Message);
            return;
        }
        sw.Stop();
        Logger.Info($"Transcribed {samples.Length} samples in {sw.ElapsedMilliseconds} ms -> {text.Length} chars");

        // A cancel (Esc) may have fired while we were transcribing.
        if (_state != SessionState.Processing)
        {
            Logger.Info("Insertion skipped: session was cancelled");
            return;
        }

        if (string.IsNullOrWhiteSpace(text))
        {
            EndSession();
            ShowBalloon("Scream", "No speech detected.");
            return;
        }

        try
        {
            await _inserter.InsertAsync(text);
        }
        catch (Exception ex)
        {
            Logger.Error("Insertion failed", ex);
            ShowBalloon("Couldn't insert text", ex.Message);
        }
        EndSession();
    }

    private void CancelRecording()
    {
        if (_state == SessionState.Recording)
            _audio.Cancel();
        EndSession();
        Logger.Info("Recording cancelled");
    }

    private void EndSession()
    {
        _pill.HidePill();
        _state = SessionState.Idle;
    }

    private void ShowBalloon(string title, string message) => Balloon?.Invoke(title, message);

    public void Dispose()
    {
        _hook.Dispose();
        _audio.Dispose();
        _whisper.Dispose();
        try { _pill.Dispose(); } catch { /* ignore */ }
    }
}
