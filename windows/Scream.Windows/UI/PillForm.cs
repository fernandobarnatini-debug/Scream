using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;
using Scream.Windows.Audio;
using static Scream.Windows.Support.NativeMethods;

namespace Scream.Windows.UI;

/// <summary>
/// The floating status pill: a small borderless, always-on-top, no-activate window at
/// the bottom-center of the primary screen. It never steals focus, so the target app
/// keeps its caret while you dictate.
/// </summary>
internal sealed class PillForm : Form
{
    private enum PillState { Listening, Transcribing }

    private readonly AudioCapture _audio;
    private readonly System.Windows.Forms.Timer _animTimer;
    private PillState _state = PillState.Listening;
    private float _displayLevel;
    private double _phase;

    public PillForm(AudioCapture audio)
    {
        _audio = audio;

        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        StartPosition = FormStartPosition.Manual;
        TopMost = true;
        DoubleBuffered = true;
        Size = new Size(240, 56);
        BackColor = Color.FromArgb(24, 24, 27);
        Region = RoundedRegion(Size, 26);

        _animTimer = new System.Windows.Forms.Timer { Interval = 33 };
        _animTimer.Tick += (_, _) => OnAnimTick();
    }

    // Keep the window from taking focus when shown.
    protected override bool ShowWithoutActivation => true;

    protected override CreateParams CreateParams
    {
        get
        {
            const int WS_EX_NOACTIVATE = 0x08000000;
            const int WS_EX_TOOLWINDOW = 0x00000080;
            const int WS_EX_TOPMOST = 0x00000008;
            var cp = base.CreateParams;
            cp.ExStyle |= WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW | WS_EX_TOPMOST;
            return cp;
        }
    }

    public void ShowListening()
    {
        _state = PillState.Listening;
        _displayLevel = 0f;
        Present();
    }

    public void ShowTranscribing()
    {
        _state = PillState.Transcribing;
        Present();
    }

    public void HidePill()
    {
        _animTimer.Stop();
        Hide();
    }

    private void Present()
    {
        PositionBottomCenter();
        if (!Visible)
            Visible = true; // ShowWithoutActivation prevents focus theft
        ShowWindow(Handle, SW_SHOWNOACTIVATE);
        TopMost = true;
        _animTimer.Start();
        Invalidate();
    }

    private void PositionBottomCenter()
    {
        var area = (Screen.PrimaryScreen ?? Screen.AllScreens[0]).WorkingArea;
        int x = area.Left + (area.Width - Width) / 2;
        int y = area.Bottom - Height - 48;
        Location = new Point(x, y);
    }

    private void OnAnimTick()
    {
        _phase += 0.35;
        if (_state == PillState.Listening)
        {
            float target = Math.Clamp(_audio.Level * 3.0f, 0f, 1f);
            _displayLevel += (target - _displayLevel) * 0.35f;
        }
        Invalidate();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.Clear(BackColor);

        var ink = Color.White;
        if (_state == PillState.Listening)
        {
            DrawBars(g, ink);
            DrawText(g, "Listening…", ink, leftPad: 92);
        }
        else
        {
            DrawSpinner(g, ink);
            DrawText(g, "Transcribing…", ink, leftPad: 46);
        }
    }

    private void DrawText(Graphics g, string text, Color ink, int leftPad)
    {
        using var font = new Font("Segoe UI", 11f, FontStyle.Regular);
        using var brush = new SolidBrush(ink);
        var size = g.MeasureString(text, font);
        g.DrawString(text, font, brush, leftPad, (Height - size.Height) / 2f);
    }

    private void DrawBars(Graphics g, Color ink)
    {
        const int bars = 5;
        const int barW = 5, gap = 5;
        int startX = 24;
        int midY = Height / 2;
        using var brush = new SolidBrush(ink);
        for (int i = 0; i < bars; i++)
        {
            double wobble = 0.35 + 0.65 * Math.Abs(Math.Sin(_phase + i * 0.9));
            double h = Math.Max(4, _displayLevel * 30 * wobble + 4);
            float x = startX + i * (barW + gap);
            g.FillRectangle(brush, new RectangleF(x, (float)(midY - h / 2), barW, (float)h));
        }
    }

    private void DrawSpinner(Graphics g, Color ink)
    {
        int cx = 26, cy = Height / 2, r = 9;
        using var pen = new Pen(Color.FromArgb(220, ink), 3f)
        {
            StartCap = LineCap.Round,
            EndCap = LineCap.Round,
        };
        float start = (float)(_phase * 40 % 360);
        g.DrawArc(pen, cx - r, cy - r, r * 2, r * 2, start, 270);
    }

    private static Region RoundedRegion(Size size, int radius)
    {
        using var path = new GraphicsPath();
        int d = radius * 2;
        path.AddArc(0, 0, d, d, 180, 90);
        path.AddArc(size.Width - d, 0, d, d, 270, 90);
        path.AddArc(size.Width - d, size.Height - d, d, d, 0, 90);
        path.AddArc(0, size.Height - d, d, d, 90, 90);
        path.CloseFigure();
        return new Region(path);
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing) _animTimer.Dispose();
        base.Dispose(disposing);
    }
}
