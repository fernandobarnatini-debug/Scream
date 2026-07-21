using System;
using System.Threading;
using System.Windows.Forms;
using Scream.Windows.App;
using Scream.Windows.Support;

namespace Scream.Windows;

internal static class Program
{
    // Unique per-user single-instance guard.
    private const string MutexName = @"Local\Scream.Windows.SingleInstance.9C7F2E4A";
    private static Mutex? _mutex;

    [STAThread]
    private static void Main()
    {
        _mutex = new Mutex(initiallyOwned: true, MutexName, out bool createdNew);
        if (!createdNew)
        {
            MessageBox.Show(
                "Scream is already running. Look for the microphone icon in the system tray " +
                "(bottom-right of the screen, near the clock).",
                "Scream", MessageBoxButtons.OK, MessageBoxIcon.Information);
            return;
        }

        // Sets EnableVisualStyles + PerMonitorV2 high-DPI (source-generated from the .csproj).
        ApplicationConfiguration.Initialize();

        Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException);
        Application.ThreadException += (_, e) => CrashHandler.Handle(e.Exception);
        AppDomain.CurrentDomain.UnhandledException += (_, e) => CrashHandler.Handle(e.ExceptionObject as Exception);

        try
        {
            Logger.Info("Scream starting");
            using var context = new TrayApplicationContext();
            Application.Run(context);
            Logger.Info("Scream exited");
        }
        catch (Exception ex)
        {
            CrashHandler.Handle(ex);
        }
        finally
        {
            _mutex?.ReleaseMutex();
            _mutex?.Dispose();
        }
    }
}
