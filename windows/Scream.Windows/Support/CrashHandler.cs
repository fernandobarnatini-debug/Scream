using System;
using System.Windows.Forms;

namespace Scream.Windows.Support;

/// <summary>Top-level exception handler: log it, show a friendly box, never die silently.</summary>
internal static class CrashHandler
{
    private static bool _shown;

    public static void Handle(Exception? ex)
    {
        Logger.Error("Unhandled exception", ex);
        if (_shown) return;
        _shown = true;
        try
        {
            MessageBox.Show(
                "Scream ran into an unexpected problem.\n\n" +
                (ex?.Message ?? "Unknown error") +
                "\n\nA detailed report was saved to:\n" + Paths.LogFile,
                "Scream", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
        catch
        {
            // Nothing more we can do.
        }
    }
}
