# Scream v0.1.0

**Fully local push-to-talk dictation — now on macOS and Windows.**

Hold a key, speak, let go — and your words are typed straight into whatever app you're
using: an email, a document, a browser text box, a chat window, anything. Every part of
this happens **on your own computer**. Your audio and your text never leave your machine
and are never sent to any server. Nothing to sign up for, no account, no cloud.

This is the **first release for Windows**, alongside the existing macOS app.

---

## Downloads

Grab the file for your computer from the **Assets** section below:

- **Windows:** `Scream-Windows.zip` — Windows 10 (64-bit) or newer.
- **macOS:** `Scream-macOS.zip` — Apple Silicon Mac running macOS 15 or newer.

New to Scream? Step-by-step guides:

- **[Install on Windows](../blob/main/docs/install-windows.md)**
- **[Troubleshooting on Windows](../blob/main/docs/troubleshooting-windows.md)**

---

## What Scream is

- **Talk instead of type.** Hold the talk key, say your sentence, release — the words
  appear where your cursor is.
- **Completely private and offline.** Transcription runs entirely on your own device.
  Nothing is uploaded. The only time Scream uses the internet is the one-time voice-model
  download when you first set it up.
- **Works almost everywhere.** Because Scream types the words for you, it works in nearly
  any app, not just special ones.
- **Choose your accuracy.** Pick a voice model that fits your computer — a small fast one,
  or a larger, more accurate one.

---

## Setting up

### Windows

1. Download and unzip **`Scream-Windows.zip`**. Inside is a single program, **`Scream.exe`**
   — there's no installer, and you don't need to install anything else (no ".NET" or extra
   downloads).
2. Double-click it. Scream lives in the **system tray** near the clock.
3. On first run, Settings opens so you can **download a voice model** (see the list below).
4. Default keys: **hold Right Ctrl** to talk (release to type), tap **F9** for hands-free
   mode, **Esc** to cancel. All of these can be changed in Settings.
5. Optional: turn on **"Start Scream when Windows starts"** in Settings.

Full walkthrough: **[Install on Windows](../blob/main/docs/install-windows.md)**.

### macOS

1. Download and unzip **`Scream-macOS.zip`**, then drag **Scream.app** into your
   **Applications** folder.
2. Open it. Follow the in-app setup to grant Microphone and Accessibility permissions and
   download a model.
3. Default: **hold `fn`** to talk, then release.

---

## Voice models

Scream downloads one voice model the first time you set it up. It's a one-time download
that stays on your computer.

**On Windows:**

| Model | Size | Notes |
|-------|------|-------|
| `base.en` | ~142 MB | Fastest. Best for older or slower PCs. |
| `small.en` | ~466 MB | **Recommended default** — a good balance of speed and accuracy. |
| `large-v3-turbo-q5_0` | ~574 MB | Most accurate. Needs a fast, modern PC. |

On macOS, the model manager offers Whisper models from Tiny (~66 MB) up to
Large v3 Turbo (~626 MB, recommended for accuracy).

---

## Please read: the "unrecognized app" warnings

Both apps are **not digitally signed** (code signing is a paid registration that a small
free project like this hasn't set up yet). Your computer will warn you **once**. This is
expected, and getting past it is quick:

- **Windows:** You'll see a blue box, **"Windows protected your PC."** Click the grey
  **"More info"** text, then click **Run anyway**. You'll only see this once.
- **macOS:** The first launch is blocked. Open **System Settings → Privacy & Security**,
  scroll down, and click **Open Anyway** next to the message about Scream, then confirm.
  Only needed once.

If Windows Defender removes the file entirely, the
**[Windows troubleshooting guide](../blob/main/docs/troubleshooting-windows.md)** explains
how to restore and allow it.

---

## Requirements

- **Windows:** Windows 10 (64-bit) or newer, and a microphone.
- **macOS:** Apple Silicon Mac, macOS 15 or newer, and a microphone.

---

## How your text gets inserted

Scream types your words by **pasting** them. It briefly borrows the clipboard, inserts your
text, and then restores whatever you had copied before. On both platforms, dictation into a
few special windows is intentionally blocked by the operating system for security — on
Windows this means programs opened **"as administrator,"** and on macOS this means secure
password fields (Scream deliberately won't type into those).

---

## Known limitations (stated honestly)

- **First Windows release.** This is version 0.1.0 for Windows, and it has **not yet been
  tested across a wide range of PCs**. Behavior may vary on different hardware and Windows
  configurations. Please report anything odd.
- **Not code-signed.** Both apps trigger a one-time "unrecognized app" warning (see above),
  and Windows Defender may occasionally quarantine the Windows app until you allow it.
- **The default keys can clash.** **Right Ctrl** and **F9** are used by some games and
  programs. If that happens, change Scream's keys in Settings.
- **Speed depends on your computer and model.** On older PCs the larger, more accurate
  models can lag; switching to **base.en** on Windows (or a smaller model on macOS) speeds
  things up.
- **Administrator windows on Windows / secure fields on macOS** won't accept dictated text,
  by design of the operating system.

Found a problem? Please open an issue and, on Windows, attach the log file from
`%APPDATA%\Scream\logs\scream.log`:
**https://github.com/fernandobarnatini-debug/Scream/issues**

---

**Thank you for trying Scream.** Everything stays on your machine — talk freely.
