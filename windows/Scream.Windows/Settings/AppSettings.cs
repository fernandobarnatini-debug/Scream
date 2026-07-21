using System;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
using Scream.Windows.Support;
using Scream.Windows.Transcription;

namespace Scream.Windows.Settings;

internal enum InsertionMethod
{
    Paste,
    Type,
}

/// <summary>User preferences, persisted as %APPDATA%\Scream\settings.json.</summary>
internal sealed class AppSettings
{
    public HotkeyOption HoldKey { get; set; } = HotkeyOption.RightCtrl;
    public HotkeyOption ToggleKey { get; set; } = HotkeyOption.F9;
    public string Model { get; set; } = ModelCatalog.DefaultModelName;
    public InsertionMethod Insertion { get; set; } = InsertionMethod.Paste;
    public bool StartWithWindows { get; set; }

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        Converters = { new JsonStringEnumConverter() },
    };

    public static AppSettings Load()
    {
        try
        {
            if (File.Exists(Paths.SettingsFile))
            {
                var json = File.ReadAllText(Paths.SettingsFile);
                var loaded = JsonSerializer.Deserialize<AppSettings>(json, JsonOptions);
                if (loaded != null)
                {
                    if (string.IsNullOrWhiteSpace(loaded.Model) || ModelCatalog.Find(loaded.Model) is null)
                        loaded.Model = ModelCatalog.DefaultModelName;
                    return loaded;
                }
            }
        }
        catch (Exception ex)
        {
            Logger.Error("Failed to load settings; using defaults", ex);
        }
        return new AppSettings();
    }

    public void Save()
    {
        try
        {
            Paths.EnsureDirectories();
            File.WriteAllText(Paths.SettingsFile, JsonSerializer.Serialize(this, JsonOptions));
            Logger.Info("Settings saved");
        }
        catch (Exception ex)
        {
            Logger.Error("Failed to save settings", ex);
        }
    }
}
