using System;
using System.Windows.Forms;
using Microsoft.Win32;
using Scream.Windows.Support;

namespace Scream.Windows.Settings;

/// <summary>Toggles "Start Scream when Windows starts" via HKCU\...\Run.</summary>
internal static class StartupManager
{
    private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string ValueName = "Scream";

    public static void Set(bool enabled)
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKey, writable: true)
                            ?? Registry.CurrentUser.CreateSubKey(RunKey);
            if (key == null) return;

            if (enabled)
            {
                var exe = Environment.ProcessPath ?? Application.ExecutablePath;
                key.SetValue(ValueName, $"\"{exe}\"");
                Logger.Info("Enabled start-with-Windows");
            }
            else if (key.GetValue(ValueName) != null)
            {
                key.DeleteValue(ValueName, throwOnMissingValue: false);
                Logger.Info("Disabled start-with-Windows");
            }
        }
        catch (Exception ex)
        {
            Logger.Error("Failed to update start-with-Windows", ex);
        }
    }

    public static bool IsEnabled()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKey);
            return key?.GetValue(ValueName) != null;
        }
        catch
        {
            return false;
        }
    }
}
