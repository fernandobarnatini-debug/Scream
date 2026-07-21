using System;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using Scream.Windows.Support;
using Whisper.net;

namespace Scream.Windows.Transcription;

internal enum ModelStatus
{
    None,
    Downloading,
    Loading,
    Ready,
    Error,
}

/// <summary>
/// Owns the warm Whisper.net model. The factory is loaded once and kept in memory;
/// a lightweight processor is created per utterance from it.
/// </summary>
internal sealed class WhisperService : IDisposable
{
    private readonly object _gate = new();
    private WhisperFactory? _factory;

    public ModelStatus Status { get; private set; } = ModelStatus.None;
    public string StatusText { get; private set; } = "No model loaded";
    public string? LoadedModel { get; private set; }

    /// <summary>Raised on any status change. May fire on a background thread.</summary>
    public event Action? StatusChanged;

    public bool IsReady
    {
        get { lock (_gate) return _factory != null && Status == ModelStatus.Ready; }
    }

    private void SetStatus(ModelStatus status, string text)
    {
        Status = status;
        StatusText = text;
        Logger.Info($"Model status: {text}");
        StatusChanged?.Invoke();
    }

    public void SetDownloading(string modelName, double fraction) =>
        SetStatus(ModelStatus.Downloading, $"Downloading {modelName} — {(int)(fraction * 100)}%");

    public void SetError(string message) =>
        SetStatus(ModelStatus.Error, $"Model error: {message}");

    /// <summary>Loads a ggml model file (the heavy work runs on a background thread).</summary>
    public async Task LoadModelAsync(ModelInfo model, string path)
    {
        SetStatus(ModelStatus.Loading, $"Loading {model.DisplayName}…");
        await Task.Run(() =>
        {
            var factory = WhisperFactory.FromPath(path);
            lock (_gate)
            {
                _factory?.Dispose();
                _factory = factory;
                LoadedModel = model.Name;
            }
        });
        SetStatus(ModelStatus.Ready, $"Ready · {model.DisplayName}");
    }

    public async Task<string> TranscribeAsync(float[] samples, CancellationToken ct = default)
    {
        WhisperFactory factory;
        lock (_gate)
        {
            factory = _factory ?? throw new InvalidOperationException("No speech model is loaded.");
        }

        using var processor = factory.CreateBuilder()
            .WithLanguage("en")
            .Build();

        var sb = new StringBuilder();
        await foreach (var segment in processor.ProcessAsync(samples, ct))
        {
            sb.Append(segment.Text);
        }
        return Clean(sb.ToString());
    }

    private static readonly Regex Brackets = new(@"\[[^\]]*\]", RegexOptions.Compiled);
    private static readonly Regex MultiSpace = new(@"\s{2,}", RegexOptions.Compiled);

    private static string Clean(string text)
    {
        text = Brackets.Replace(text, "");
        text = MultiSpace.Replace(text, " ");
        return text.Trim();
    }

    public void Dispose()
    {
        lock (_gate)
        {
            _factory?.Dispose();
            _factory = null;
        }
    }
}
