using System;
using System.Runtime.InteropServices;
using Scream.Windows.Support;
using static Scream.Windows.Support.NativeMethods;

namespace Scream.Windows.Hotkeys;

internal readonly struct KeyEvent
{
    public readonly uint VkCode;
    public readonly bool IsDown;

    public KeyEvent(uint vkCode, bool isDown)
    {
        VkCode = vkCode;
        IsDown = isDown;
    }
}

/// <summary>
/// Global WH_KEYBOARD_LL hook. OnKey returns true to swallow the event so it never
/// reaches other apps. Must be installed on a thread that pumps messages.
/// </summary>
internal sealed class KeyboardHook : IDisposable
{
    private readonly LowLevelKeyboardProc _proc; // kept alive so the delegate isn't GC'd
    private IntPtr _hookId = IntPtr.Zero;

    public Func<KeyEvent, bool>? OnKey;

    public KeyboardHook()
    {
        _proc = HookCallback;
    }

    public bool IsInstalled => _hookId != IntPtr.Zero;

    public bool Install()
    {
        if (_hookId != IntPtr.Zero) return true;
        _hookId = SetWindowsHookEx(WH_KEYBOARD_LL, _proc, GetModuleHandle(null), 0);
        if (_hookId == IntPtr.Zero)
        {
            Logger.Error($"Failed to install keyboard hook (error {Marshal.GetLastWin32Error()})");
            return false;
        }
        Logger.Info("Keyboard hook installed");
        return true;
    }

    private IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode >= 0)
        {
            try
            {
                var data = Marshal.PtrToStructure<KBDLLHOOKSTRUCT>(lParam);

                // Ignore keystrokes we synthesized ourselves (tagged with our sentinel).
                if ((ulong)data.dwExtraInfo.ToInt64() == InjectedTagValue)
                    return CallNextHookEx(_hookId, nCode, wParam, lParam);

                int msg = (int)wParam;
                bool isDown = msg == WM_KEYDOWN || msg == WM_SYSKEYDOWN;
                bool isUp = msg == WM_KEYUP || msg == WM_SYSKEYUP;

                if (isDown || isUp)
                {
                    var handler = OnKey;
                    if (handler != null && handler(new KeyEvent(data.vkCode, isDown)))
                        return (IntPtr)1; // swallow
                }
            }
            catch (Exception ex)
            {
                Logger.Error("Keyboard hook callback error", ex);
            }
        }
        return CallNextHookEx(_hookId, nCode, wParam, lParam);
    }

    public void Dispose()
    {
        if (_hookId != IntPtr.Zero)
        {
            UnhookWindowsHookEx(_hookId);
            _hookId = IntPtr.Zero;
            Logger.Info("Keyboard hook removed");
        }
    }
}
