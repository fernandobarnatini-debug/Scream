using System;
using System.Drawing;
using System.Reflection;
using System.Windows.Forms;
using Scream.Windows.Settings;
using Scream.Windows.Support;
using Scream.Windows.UI;

namespace Scream.Windows.App;

/// <summary>
/// Runs the app from the system tray: a microphone icon with Settings and Quit, the
/// live model status, first-run Settings, and balloon notifications.
/// </summary>
internal sealed class TrayApplicationContext : ApplicationContext
{
    /// <summary>The app icon, loaded once for the tray and every window.</summary>
    public static Icon SharedIcon { get; private set; } = SystemIcons.Application;

    private readonly NotifyIcon _tray;
    private readonly ToolStripMenuItem _statusItem;
    private readonly AppController _controller;
    private SettingsForm? _settingsForm;

    public TrayApplicationContext()
    {
        Paths.EnsureDirectories();
        SharedIcon = LoadIcon();

        _controller = new AppController { Balloon = ShowBalloon };

        _statusItem = new ToolStripMenuItem("Starting…") { Enabled = false };
        var menu = new ContextMenuStrip();
        menu.Items.Add(_statusItem);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Settings…", null, (_, _) => OpenSettings());
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Quit", null, (_, _) => Quit());

        _tray = new NotifyIcon
        {
            Icon = SharedIcon,
            Text = "Scream",
            Visible = true,
            ContextMenuStrip = menu,
        };
        _tray.DoubleClick += (_, _) => OpenSettings();

        _controller.Whisper.StatusChanged += () => _controller.Post(UpdateStatus);

        _controller.Start();
        UpdateStatus();

        if (!_controller.CurrentModelDownloaded)
        {
            Logger.Info("No model downloaded; opening Settings on first run");
            OpenSettings();
        }
    }

    private static Icon LoadIcon()
    {
        try
        {
            using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("scream.ico");
            if (stream != null) return new Icon(stream);
        }
        catch (Exception ex)
        {
            Logger.Warn($"Icon load failed: {ex.Message}");
        }
        return SystemIcons.Application;
    }

    private void UpdateStatus()
    {
        var text = _controller.Whisper.StatusText;
        _statusItem.Text = text;
        _tray.Text = text.Length > 63 ? text.Substring(0, 63) : text;
    }

    private void OpenSettings()
    {
        if (_settingsForm == null || _settingsForm.IsDisposed)
        {
            _settingsForm = new SettingsForm(_controller);
            _settingsForm.FormClosed += (_, _) => _settingsForm = null;
            _settingsForm.Show();
        }

        _settingsForm.WindowState = FormWindowState.Normal;
        _settingsForm.Activate();
        _settingsForm.BringToFront();
    }

    private void ShowBalloon(string title, string message)
    {
        try
        {
            _tray.BalloonTipTitle = title;
            _tray.BalloonTipText = message;
            _tray.ShowBalloonTip(4000);
        }
        catch (Exception ex)
        {
            Logger.Warn($"Balloon failed: {ex.Message}");
        }
    }

    private void Quit()
    {
        Logger.Info("Quit requested");
        _tray.Visible = false;
        _controller.Dispose();
        _tray.Dispose();
        ExitThread();
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            try { _controller.Dispose(); } catch { /* ignore */ }
            try { _tray.Dispose(); } catch { /* ignore */ }
        }
        base.Dispose(disposing);
    }
}
