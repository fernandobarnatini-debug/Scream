using System;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using Scream.Windows.Support;

namespace Scream.Windows.Transcription;

/// <summary>Downloads ggml model files from Hugging Face into %APPDATA%\Scream\Models.</summary>
internal static class ModelDownloader
{
    private static readonly HttpClient Http = new(new HttpClientHandler
    {
        AutomaticDecompression = DecompressionMethods.None,
    })
    {
        Timeout = TimeSpan.FromMinutes(30),
    };

    public static string LocalPath(ModelInfo model) => Path.Combine(Paths.Models, model.FileName);

    public static bool IsDownloaded(ModelInfo model)
    {
        var path = LocalPath(model);
        return File.Exists(path) && new FileInfo(path).Length > 1_000_000;
    }

    /// <summary>Streams the model to disk, reporting 0..1 progress. Throws on network failure.</summary>
    public static async Task DownloadAsync(ModelInfo model, IProgress<double> progress, CancellationToken ct)
    {
        Paths.EnsureDirectories();
        var finalPath = LocalPath(model);
        var tempPath = finalPath + ".download";
        Logger.Info($"Downloading model {model.Name} from {model.DownloadUrl}");

        try
        {
            using var response = await Http.GetAsync(
                model.DownloadUrl, HttpCompletionOption.ResponseHeadersRead, ct);
            response.EnsureSuccessStatusCode();

            var total = response.Content.Headers.ContentLength ?? (long)model.SizeMB * 1024 * 1024;
            await using var httpStream = await response.Content.ReadAsStreamAsync(ct);
            await using (var file = new FileStream(
                tempPath, FileMode.Create, FileAccess.Write, FileShare.None, 1 << 20, useAsync: true))
            {
                var buffer = new byte[1 << 20];
                long read = 0;
                int n;
                while ((n = await httpStream.ReadAsync(buffer, ct)) > 0)
                {
                    await file.WriteAsync(buffer.AsMemory(0, n), ct);
                    read += n;
                    if (total > 0)
                        progress.Report(Math.Min(1.0, (double)read / total));
                }
            }

            if (File.Exists(finalPath)) File.Delete(finalPath);
            File.Move(tempPath, finalPath);
            progress.Report(1.0);
            Logger.Info($"Model {model.Name} downloaded ({new FileInfo(finalPath).Length} bytes)");
        }
        catch
        {
            try { if (File.Exists(tempPath)) File.Delete(tempPath); } catch { /* ignore */ }
            throw;
        }
    }
}
