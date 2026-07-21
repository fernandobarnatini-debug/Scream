using System;
using System.IO;
using System.Text;

namespace Scream.Windows.Support;

/// <summary>
/// Dead-simple rolling append log at %APPDATA%\Scream\logs\scream.log. Thread-safe
/// and swallows its own errors so logging can never crash the app.
/// </summary>
internal static class Logger
{
    private static readonly object Gate = new();
    private const long MaxBytes = 2 * 1024 * 1024;

    public static void Info(string message) => Write("INFO", message);
    public static void Warn(string message) => Write("WARN", message);

    public static void Error(string message, Exception? ex = null) =>
        Write("ERROR", ex is null ? message : $"{message}: {ex}");

    private static void Write(string level, string message)
    {
        try
        {
            lock (Gate)
            {
                Paths.EnsureDirectories();
                Roll();
                var line = $"{DateTime.Now:yyyy-MM-dd HH:mm:ss.fff} [{level}] {message}{Environment.NewLine}";
                File.AppendAllText(Paths.LogFile, line, Encoding.UTF8);
            }
        }
        catch
        {
            // Logging must never throw.
        }
    }

    private static void Roll()
    {
        try
        {
            var fi = new FileInfo(Paths.LogFile);
            if (fi.Exists && fi.Length > MaxBytes)
            {
                var archived = Paths.LogFile + ".1";
                if (File.Exists(archived)) File.Delete(archived);
                File.Move(Paths.LogFile, archived);
            }
        }
        catch
        {
            // Ignore roll failures.
        }
    }
}
