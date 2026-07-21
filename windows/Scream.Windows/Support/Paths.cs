using System;
using System.IO;

namespace Scream.Windows.Support;

/// <summary>Well-known locations under %APPDATA%\Scream.</summary>
internal static class Paths
{
    public static string Root { get; } = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Scream");

    public static string Models { get; } = Path.Combine(Root, "Models");
    public static string Logs { get; } = Path.Combine(Root, "logs");
    public static string SettingsFile { get; } = Path.Combine(Root, "settings.json");
    public static string LogFile { get; } = Path.Combine(Logs, "scream.log");

    public static void EnsureDirectories()
    {
        Directory.CreateDirectory(Root);
        Directory.CreateDirectory(Models);
        Directory.CreateDirectory(Logs);
    }
}
