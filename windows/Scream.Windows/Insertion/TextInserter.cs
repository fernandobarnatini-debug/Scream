using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using Scream.Windows.Settings;
using Scream.Windows.Support;
using static Scream.Windows.Support.NativeMethods;

namespace Scream.Windows.Insertion;

/// <summary>
/// Inserts transcribed text into whatever app has focus. Default is a clipboard
/// paste (save clipboard, set transcript, Ctrl+V, restore clipboard); the alternate
/// is direct Unicode typing. All methods must run on the UI (STA) thread.
/// </summary>
internal sealed class TextInserter
{
    private readonly Func<AppSettings> _settings;

    public TextInserter(Func<AppSettings> settings)
    {
        _settings = settings;
    }

    public async Task InsertAsync(string text)
    {
        if (_settings().Insertion == InsertionMethod.Type)
        {
            TypeUnicode(text);
            Logger.Info($"Inserted {text.Length} chars via typing");
            return;
        }

        await InsertViaPasteAsync(text);
        Logger.Info($"Inserted {text.Length} chars via paste");
    }

    private static async Task InsertViaPasteAsync(string text)
    {
        string? backupText = null;
        try
        {
            if (Clipboard.ContainsText())
                backupText = Clipboard.GetText();
        }
        catch (Exception ex)
        {
            Logger.Warn($"Could not read existing clipboard: {ex.Message}");
        }

        SetClipboardText(text);
        await Task.Delay(60);   // let the target app's message loop settle
        SendCtrlV();

        await Task.Delay(300);  // let the paste complete before restoring
        try
        {
            if (backupText != null)
                SetClipboardText(backupText);
            else
                Clipboard.Clear();
        }
        catch (Exception ex)
        {
            Logger.Warn($"Could not restore clipboard: {ex.Message}");
        }
    }

    private static void SetClipboardText(string text)
    {
        // The clipboard can be transiently locked by another app; retry briefly.
        for (int attempt = 0; attempt < 5; attempt++)
        {
            try
            {
                if (string.IsNullOrEmpty(text))
                    Clipboard.Clear();
                else
                    Clipboard.SetText(text);
                return;
            }
            catch (Exception ex)
            {
                if (attempt == 4)
                {
                    Logger.Warn($"Clipboard set failed: {ex.Message}");
                    return;
                }
                Thread.Sleep(30);
            }
        }
    }

    private static void SendCtrlV()
    {
        var inputs = new[]
        {
            KeyInput(VK_CONTROL, keyUp: false),
            KeyInput(VK_V, keyUp: false),
            KeyInput(VK_V, keyUp: true),
            KeyInput(VK_CONTROL, keyUp: true),
        };
        SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<INPUT>());
    }

    private static INPUT KeyInput(ushort vk, bool keyUp) => new()
    {
        type = INPUT_KEYBOARD,
        U = new InputUnion
        {
            ki = new KEYBDINPUT
            {
                wVk = vk,
                wScan = 0,
                dwFlags = keyUp ? KEYEVENTF_KEYUP : 0,
                time = 0,
                dwExtraInfo = InjectedTag,
            },
        },
    };

    private static void TypeUnicode(string text)
    {
        const int batchChars = 40;
        var buffer = new List<INPUT>(batchChars * 2);
        foreach (char c in text)
        {
            buffer.Add(UnicodeInput(c, keyUp: false));
            buffer.Add(UnicodeInput(c, keyUp: true));
            if (buffer.Count >= batchChars * 2)
            {
                SendInput((uint)buffer.Count, buffer.ToArray(), Marshal.SizeOf<INPUT>());
                buffer.Clear();
                Thread.Sleep(4);
            }
        }
        if (buffer.Count > 0)
            SendInput((uint)buffer.Count, buffer.ToArray(), Marshal.SizeOf<INPUT>());
    }

    private static INPUT UnicodeInput(char c, bool keyUp) => new()
    {
        type = INPUT_KEYBOARD,
        U = new InputUnion
        {
            ki = new KEYBDINPUT
            {
                wVk = 0,
                wScan = c,
                dwFlags = KEYEVENTF_UNICODE | (keyUp ? KEYEVENTF_KEYUP : 0),
                time = 0,
                dwExtraInfo = InjectedTag,
            },
        },
    };
}
