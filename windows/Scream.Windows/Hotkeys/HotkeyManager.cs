using System;
using System.Diagnostics;
using Scream.Windows.Settings;

namespace Scream.Windows.Hotkeys;

internal enum DictationCommand
{
    BeginHold,
    EndHold,
    CancelHold,
    BeginToggle,
    EndToggle,
    CancelActive,
}

/// <summary>
/// Turns raw key events into dictation commands: hold-to-talk, tap-to-toggle, and
/// Esc-to-cancel. Auto-repeat key-downs are ignored by tracking pressed state, and
/// the configured trigger keys are always swallowed on both edges so global key
/// state (e.g. Ctrl, Caps Lock) stays balanced.
/// </summary>
internal sealed class HotkeyManager
{
    private const uint VK_ESCAPE = 0x1B;
    private static readonly TimeSpan MinHold = TimeSpan.FromMilliseconds(250);

    private enum Mode { None, Hold, Toggle }

    private readonly Func<AppSettings> _settings;
    public Action<DictationCommand>? OnCommand;

    private Mode _mode = Mode.None;
    private bool _holdDown;
    private bool _toggleDown;
    private long _holdStartTicks;

    public HotkeyManager(Func<AppSettings> settings)
    {
        _settings = settings;
    }

    /// <summary>Drops all per-key state; cancels any active session. Used after a hook reset.</summary>
    public void Reset()
    {
        _holdDown = false;
        _toggleDown = false;
        _holdStartTicks = 0;
        if (_mode != Mode.None)
        {
            _mode = Mode.None;
            OnCommand?.Invoke(DictationCommand.CancelActive);
        }
    }

    /// <summary>Returns true to swallow the event.</summary>
    public bool Handle(KeyEvent e)
    {
        var settings = _settings();
        uint holdVk = settings.HoldKey.VirtualKey();
        uint toggleVk = settings.ToggleKey.VirtualKey();

        // Esc cancels an active session (and is swallowed only while active).
        if (e.VkCode == VK_ESCAPE && e.IsDown && _mode != Mode.None)
        {
            _mode = Mode.None;
            OnCommand?.Invoke(DictationCommand.CancelActive);
            return true;
        }

        if (holdVk != 0 && e.VkCode == holdVk)
        {
            HandleHold(e.IsDown);
            return true;
        }

        if (toggleVk != 0 && e.VkCode == toggleVk)
        {
            HandleToggle(e.IsDown);
            return true;
        }

        return false;
    }

    private void HandleHold(bool isDown)
    {
        if (isDown)
        {
            if (_holdDown) return; // ignore auto-repeat
            _holdDown = true;
            if (_mode == Mode.None)
            {
                _mode = Mode.Hold;
                _holdStartTicks = Stopwatch.GetTimestamp();
                OnCommand?.Invoke(DictationCommand.BeginHold);
            }
        }
        else
        {
            if (!_holdDown) return;
            _holdDown = false;
            if (_mode == Mode.Hold)
            {
                _mode = Mode.None;
                var elapsed = Stopwatch.GetElapsedTime(_holdStartTicks);
                OnCommand?.Invoke(elapsed < MinHold
                    ? DictationCommand.CancelHold
                    : DictationCommand.EndHold);
            }
        }
    }

    private void HandleToggle(bool isDown)
    {
        if (!isDown)
        {
            _toggleDown = false;
            return;
        }
        if (_toggleDown) return; // ignore auto-repeat
        _toggleDown = true;

        switch (_mode)
        {
            case Mode.None:
                _mode = Mode.Toggle;
                OnCommand?.Invoke(DictationCommand.BeginToggle);
                break;
            case Mode.Toggle:
                _mode = Mode.None;
                OnCommand?.Invoke(DictationCommand.EndToggle);
                break;
            case Mode.Hold:
                break;
        }
    }
}
