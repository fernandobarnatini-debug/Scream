namespace Scream.Windows.Settings;

/// <summary>Fixed set of keys the user can pick for the hold and toggle triggers.</summary>
internal enum HotkeyOption
{
    None,
    RightCtrl,
    RightAlt,
    CapsLock,
    F8,
    F9,
    Pause,
}

internal static class HotkeyOptions
{
    /// <summary>Windows virtual-key code, or 0 for None.</summary>
    public static uint VirtualKey(this HotkeyOption option) => option switch
    {
        HotkeyOption.RightCtrl => 0xA3, // VK_RCONTROL
        HotkeyOption.RightAlt => 0xA5,  // VK_RMENU
        HotkeyOption.CapsLock => 0x14,  // VK_CAPITAL
        HotkeyOption.F8 => 0x77,        // VK_F8
        HotkeyOption.F9 => 0x78,        // VK_F9
        HotkeyOption.Pause => 0x13,     // VK_PAUSE
        _ => 0,
    };

    public static string Label(this HotkeyOption option) => option switch
    {
        HotkeyOption.None => "None",
        HotkeyOption.RightCtrl => "Right Ctrl",
        HotkeyOption.RightAlt => "Right Alt",
        HotkeyOption.CapsLock => "Caps Lock",
        HotkeyOption.F8 => "F8",
        HotkeyOption.F9 => "F9",
        HotkeyOption.Pause => "Pause",
        _ => option.ToString(),
    };
}
