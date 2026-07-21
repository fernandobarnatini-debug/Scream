# Scream on Windows — Troubleshooting

If something isn't working, don't worry. Almost every problem falls into one of the
situations below, and each one has a simple fix. Find the heading that sounds like your
problem and follow the numbered steps.

If you're just getting started, the **[Install guide](install-windows.md)** covers setup
from the beginning.

---

## The Scream file disappeared after downloading (Windows Defender removed it)

Sometimes Windows Defender (the built-in antivirus) is extra cautious about a brand-new
program it hasn't seen before, and it quietly tucks the Scream file away into a
"quarantine." The file didn't do anything wrong — Defender is just being careful. Here's
how to get it back and tell Windows it's allowed.

1. Press the **Windows key**, type **Windows Security**, and press **Enter**.
2. In the window that opens, click **Virus & threat protection**.
3. Click **Protection history** (a link under the "Current threats" area).
4. Look through the list for an item mentioning **Scream** or **Scream.exe**. Click it to
   open it.
5. Find the **Actions** dropdown (or button) and choose **Restore**. This brings the file
   back.
6. If you're offered the choice, pick **Allow on device** so Defender doesn't remove it
   again.

If restoring feels fiddly, an easy alternative is to add Scream to Defender's "allowed"
list, then download it fresh:

1. In **Windows Security**, go to **Virus & threat protection**.
2. Under **Virus & threat protection settings**, click **Manage settings**.
3. Scroll down to **Exclusions** and click **Add or remove exclusions**.
4. Click **Add an exclusion → Folder**, and choose the folder where you keep Scream (for
   example, the **Scream-Windows** folder in your Documents).
5. Now re-download and unzip Scream from the
   **[Releases page](https://github.com/fernandobarnatini-debug/Scream/releases/latest)**;
   Defender will leave it alone this time.

---

## Nothing happens when I talk / no words appear (microphone is blocked)

If you hold the key and speak but nothing gets typed, the most common cause is that Windows
is stopping Scream from hearing your microphone. This is a Windows privacy setting, and
turning it back on takes less than a minute.

1. Press the **Windows key**, type **Microphone privacy settings**, and press **Enter**.
   (Or open **Settings → Privacy & security → Microphone**.)
2. Make sure the top switch, **Microphone access**, is turned **On**.
3. Make sure **Let apps access your microphone** is turned **On**.
4. Scroll down to the switch labelled **Let desktop apps access your microphone** and turn
   it **On**. **This is the important one for Scream** — Scream is a "desktop app," and
   this switch is often off by default.
5. Close Settings and try dictating again (hold **Right Ctrl**, speak, let go).

Two more things worth a quick check:

- **The right microphone is selected.** If your PC has more than one microphone (say, a
  built-in one and a headset), Windows might be listening to the wrong one. Right-click the
  little **speaker icon** near the clock, choose **Sound settings**, and under **Input**
  pick the microphone you're actually speaking into.
- **The microphone isn't muted.** Some laptops and headsets have a physical mute button or
  a mute key on the keyboard. Make sure it isn't on.

---

## Dictation is slow — there's a long wait before my words appear

On older or slower PCs, the most accurate voice models can take a while to think. The fix
is to switch to the **fastest** model, which is lighter on your PC.

1. Right-click the Scream icon near the clock (bottom-right, by the clock) and open
   **Settings**.
2. In the list of voice models, choose **base.en** (about 142 MB). It's the fastest one.
3. If you haven't downloaded it before, click **Download** and wait for it to finish.
4. Once it's selected, try dictating again. It should respond noticeably quicker.

**base.en** is a little less precise than the bigger models, but on an older PC the speed
is usually well worth it. The first sentence after switching may still take a moment while
Scream warms up; after that it's quick.

---

## The talk key does something else in a game or another program

Scream listens for **Right Ctrl** to talk and **F9** for hands-free mode. Some games and
programs also use those keys, so they can bump into each other — for example, a game might
treat Right Ctrl as "crouch."

You have two easy options:

- **Change Scream's keys.** Right-click the Scream icon near the clock, open **Settings**,
  and look for the section about hotkeys or shortcuts. Click the key you want to change,
  then press a different key that nothing else uses. A rarely used key works well.
- **Quit Scream while you play.** Right-click the Scream icon and choose **Quit**. The game
  gets its keys back. When you want to dictate again, just open Scream from the Start menu.

---

## Words won't type into certain windows (administrator windows)

You may notice that dictation works everywhere *except* a few special windows. If a program
was opened **"as administrator"** (a higher-permission mode Windows uses for system tools),
Windows deliberately blocks ordinary programs — including Scream — from typing into it.
This is a Windows security rule, not a bug in Scream, and it's there to keep you safe.

What to do:

- For everyday writing — emails, documents, web browsers, chat, Notepad — this never comes
  up, so you can usually ignore it.
- If you really need to dictate into an administrator window, the workaround is to close
  it, dictate your text into an ordinary window (like Notepad), then **copy and paste** it
  where you need it.

---

## Scream won't open at all

1. Make sure you **unzipped** the download first. Scream won't run from *inside* the zip
   file — you need to **Extract All** first (see Step 2 of the
   [Install guide](install-windows.md)).
2. If you saw the blue **"Windows protected your PC"** box and closed it, that's why
   nothing opened. Double-click Scream again, click the grey **"More info"** text, then
   click **Run anyway**. (See Step 3 of the Install guide.)
3. If it seems to open but you can't find any window, remember Scream lives **near the
   clock**, not as a big window. Click the little **upward arrow (⌃)** next to the clock to
   reveal hidden icons.

---

## I opened Settings but there's no voice model / it forgot my model

Scream needs one voice model downloaded before it can turn speech into text.

1. Right-click the Scream icon near the clock and open **Settings**.
2. Check whether a model shows as downloaded/ready. If none is, choose **small.en** (the
   recommended one) and click **Download**.
3. Wait for the download bar to finish. The models are large, so on a slow connection this
   can take several minutes.

---

## Where to find the log file (for reporting a problem)

If you ask for help, it's very useful to send along Scream's **log file** — a plain text
diary of what Scream has been doing. Here's how to find it:

1. Press the **Windows key + R** together. A small **Run** box appears.
2. Type exactly this and press **Enter**:

   ```
   %APPDATA%\Scream\logs
   ```

3. A folder opens containing a file named **`scream.log`**. That's the one.
4. You can attach that file to an email, or right-click it, choose **Open with → Notepad**,
   and copy the last part of it into your message.

For reference, this is also where Scream keeps its other files, in case you're ever asked
for them:

- **Log:** `%APPDATA%\Scream\logs\scream.log`
- **Settings:** `%APPDATA%\Scream\settings.json`
- **Voice models:** `%APPDATA%\Scream\Models`

(`%APPDATA%` is a shortcut Windows understands that points to your personal app-data
folder. You can paste it straight into the Run box or into any File Explorer address bar.)

---

Still stuck? Open an **issue** on the Scream project page and include your **`scream.log`**
file and a short description of what happened:
**https://github.com/fernandobarnatini-debug/Scream/issues**
