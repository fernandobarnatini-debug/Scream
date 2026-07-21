using System.Collections.Generic;
using System.Linq;

namespace Scream.Windows.Transcription;

/// <summary>A downloadable Whisper ggml model.</summary>
internal sealed record ModelInfo(string Name, string DisplayName, int SizeMB, string Blurb)
{
    /// <summary>Both the local filename and the Hugging Face filename are ggml-{name}.bin.</summary>
    public string FileName => $"ggml-{Name}.bin";

    public string DownloadUrl =>
        $"https://huggingface.co/ggerganov/whisper.cpp/resolve/main/{FileName}";
}

internal static class ModelCatalog
{
    public const string DefaultModelName = "small.en";

    public static readonly IReadOnlyList<ModelInfo> All = new[]
    {
        new ModelInfo("base.en", "Base (English)", 142, "Fast, English"),
        new ModelInfo("small.en", "Small (English)", 466, "Balanced, English — recommended"),
        new ModelInfo("large-v3-turbo-q5_0", "Large v3 Turbo", 574, "Best accuracy, slower"),
    };

    public static ModelInfo? Find(string name) => All.FirstOrDefault(m => m.Name == name);

    public static ModelInfo Default => Find(DefaultModelName)!;
}
