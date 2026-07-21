# Installing Scream on Windows

Scream lets you talk to your computer instead of typing. You hold a key, say what you
want, let go — and your words appear in whatever you were writing in: an email, a Word
document, a text box on a website, anything. Everything happens right on your own PC.
Your voice and your words are never sent over the internet to anyone.

This guide walks you through it one step at a time. Take your time — there's no rush, and
you can't break anything.

**What you need:** A Windows PC (Windows 10 or newer, 64-bit) and a microphone. Most
laptops already have a built-in microphone, so you're probably all set.

---

## Step 1 — Download Scream

1. Open your web browser and go to the Scream **Releases** page:
   **https://github.com/fernandobarnatini-debug/Scream/releases/latest**
2. Scroll down a little until you see a section called **Assets**.
3. Click the file named **`Scream-Windows.zip`** to download it.
4. Your browser will save it — usually into your **Downloads** folder. If a small bar
   appears at the top or bottom of the browser asking whether to keep the file, choose
   **Keep**. (Some browsers are cautious about files they don't recognize. This one is
   safe.)

---

## Step 2 — Unzip the file

The file you downloaded is a "zip," which is like a folder that's been squeezed small.
You need to open it up first.

1. Open your **Downloads** folder (you can find it in the left-hand column of any File
   Explorer window, or press the **Windows key**, type *Downloads*, and press **Enter**).
2. Find **`Scream-Windows.zip`**. **Right-click** it and choose **Extract All…**
3. A window pops up. Click **Extract** in the bottom corner.
4. A new regular folder called **Scream-Windows** opens up. Inside it is a folder called
   **Scream** — open that one too. You'll see a lot of files; the only one you need is the
   program called **`Scream`** (it may show as `Scream.exe`, with a little microphone icon).
   The other files are parts of the app — just leave them where they are.

> **Tip:** If you'd like to keep Scream somewhere tidy, you can drag the **Scream-Windows**
> folder from Downloads to your **Documents** folder first. It works from anywhere — this
> just keeps it easy to find later.

---

## Step 3 — Open Scream for the first time (the blue warning screen)

Double-click the **`Scream`** program to start it.

The very first time, Windows will show a blue box that says
**"Windows protected your PC."** Don't worry — this is normal. Windows shows this message
for any brand-new program it hasn't seen many times before. Scream is safe; it simply
hasn't gone through the paid registration that would make this message go away.

Here's how to get past it:

1. In the blue box, click the small grey words **"More info."** (They're easy to miss —
   they sit just above the buttons.)
2. A new button appears at the bottom that says **Run anyway**. Click it.

That's the last time you'll ever see that screen. From now on, Scream just opens.

---

## Step 4 — Find Scream near your clock

Scream doesn't open a big window. Instead it tucks itself into the **system tray** — the
little row of tiny icons at the **bottom-right of your screen, next to the clock**.

1. Look for a small Scream icon down there. If you don't see it, click the little
   **upward-pointing arrow (⌃)** next to the clock — some icons hide behind it.
2. You can **right-click** the Scream icon at any time to open **Settings** or to **Quit**.

The first time you run it, Scream should open its **Settings** window on its own so you can
download a voice model. If it doesn't, right-click the tray icon and choose **Settings**.

---

## Step 5 — Download a voice model

A "voice model" is the part that actually understands speech. Scream needs to download one
the first time. It's a one-time download that's saved on your PC forever after.

In the Settings window you'll see a few choices. Here's what they mean in plain terms:

| Model | Size | Best for |
|-------|------|----------|
| **base.en** | about 142 MB | The fastest. Good on older or slower PCs. A little less accurate. |
| **small.en** | about 466 MB | **The recommended one.** A great balance of speed and accuracy. Start here. |
| **large-v3-turbo-q5_0** | about 574 MB | The most accurate, but it needs a newer, faster PC to keep up. |

**Our suggestion:** Click **small.en**. If you later find it feels slow on your PC, you can
come back and switch to **base.en** (see the troubleshooting guide).

1. Click the model you want (start with **small.en**).
2. Click the **Download** button next to it.
3. Wait for the download bar to fill up. Depending on your internet speed this can take a
   few minutes — the models are fairly large. You only ever do this once.
4. When it's finished, the model shows as ready/downloaded. You're all set.

---

## Step 6 — Let Scream hear your microphone

The first time you actually talk to Scream, Windows may pop up a small question asking
whether to **let Scream use your microphone**. Click **Yes** (or **Allow**).

If it doesn't ask, don't worry — that usually means it already has permission. If you find
later that nothing gets typed and you suspect the microphone, the troubleshooting guide has
a section titled *"Windows is blocking the microphone"* that fixes it.

---

## Step 7 — Your first dictation 🎤

Now for the fun part. Let's put some words on the screen.

1. Open **Notepad** (press the **Windows key**, type *Notepad*, and press **Enter**). This
   gives you a nice empty page to practice in.
2. Click once inside the white Notepad area so the blinking cursor is there. This tells
   Windows that's where your words should go.
3. Find the **Right Ctrl** key on your keyboard. It's the **Ctrl** key on the
   **right-hand** side of the space bar, near the bottom-right of your keyboard.
4. **Press and HOLD** the Right Ctrl key. Keep holding it.
5. While holding, say a sentence clearly, like:
   *"Hello, this is my first time using Scream."*
6. **Let go** of the Right Ctrl key.

After a moment, your sentence types itself right into Notepad. 🎉

That's the whole idea: **hold Right Ctrl, talk, let go.** You can do this in almost any
program — emails, web pages, documents, chat windows.

> **Hands-free mode:** If you'd rather not hold the key the whole time, tap **F9** once to
> turn talking *on*, speak as long as you like, then tap **F9** again to turn it *off*.
> Press **Esc** at any time to cancel what you were saying.

---

## Optional — Start Scream automatically

If you'd like Scream to be ready every time you turn on your PC:

1. Right-click the Scream icon near the clock and open **Settings**.
2. Turn on the checkbox labelled **"Start Scream when Windows starts."**

Now it's always there waiting whenever you want to talk.

---

## A note on privacy

Everything Scream does happens **on your own PC**. Your voice is never recorded to the
internet, and your words are never sent anywhere. That's true even the first time you use
it. The only thing that uses the internet is the one-time model download in Step 5.

---

If something doesn't go the way this guide describes, don't worry — see
**[Troubleshooting on Windows](troubleshooting-windows.md)**. It covers the handful of
common hiccups and exactly how to fix each one.
