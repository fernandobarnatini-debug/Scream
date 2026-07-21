using System;
using System.Drawing;
using System.Threading;
using System.Windows.Forms;
using Scream.Windows.App;
using Scream.Windows.Settings;
using Scream.Windows.Transcription;

namespace Scream.Windows.UI;

/// <summary>The settings window: hotkeys, model download/activate, insertion, and startup.</summary>
internal sealed class SettingsForm : Form
{
    private readonly AppController _controller;

    private readonly ComboBox _holdCombo = NewCombo();
    private readonly ComboBox _toggleCombo = NewCombo();
    private readonly ComboBox _insertionCombo = NewCombo();
    private readonly ComboBox _modelCombo = NewCombo();
    private readonly Button _modelButton = new() { AutoSize = true, Text = "Download & activate" };
    private readonly ProgressBar _progress = new() { Height = 18, Dock = DockStyle.Fill };
    private readonly Label _modelStatus = new() { AutoSize = true, ForeColor = Color.DimGray };
    private readonly CheckBox _startupCheck = new() { AutoSize = true, Text = "Start Scream when Windows starts" };

    private CancellationTokenSource? _cts;
    private bool _loading;

    private sealed record OptionItem(HotkeyOption Value)
    {
        public override string ToString() => Value.Label();
    }

    private sealed record ModelItem(ModelInfo Info)
    {
        public override string ToString() => $"{Info.DisplayName}  (~{Info.SizeMB} MB) — {Info.Blurb}";
    }

    private sealed record InsertItem(InsertionMethod Method, string Text)
    {
        public override string ToString() => Text;
    }

    public SettingsForm(AppController controller)
    {
        _controller = controller;

        Text = "Scream Settings";
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        MinimizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        AutoScaleMode = AutoScaleMode.Dpi;
        ClientSize = new Size(470, 508);
        Padding = new Padding(16);
        try { Icon = TrayApplicationContext.SharedIcon; } catch { /* ignore */ }

        BuildLayout();
        LoadFromSettings();

        _controller.Whisper.StatusChanged += OnWhisperStatusChanged;
        FormClosed += (_, _) =>
        {
            _controller.Whisper.StatusChanged -= OnWhisperStatusChanged;
            _cts?.Cancel();
        };
    }

    private static ComboBox NewCombo() => new()
    {
        DropDownStyle = ComboBoxStyle.DropDownList,
        Width = 220,
    };

    private void BuildLayout()
    {
        var root = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 2,
            AutoSize = true,
            GrowStyle = TableLayoutPanelGrowStyle.AddRows,
        };
        root.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 150));
        root.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));

        AddRow(root, "Hold to talk", _holdCombo);
        AddCaption(root, "While Scream is running, this key is reserved for dictation and won't act as a normal key.");
        AddRow(root, "Toggle (tap on/off)", _toggleCombo);
        AddRow(root, "Insert text by", _insertionCombo);

        AddSpacer(root, 8);
        AddHeader(root, "Speech model");
        AddFullRow(root, _modelCombo);

        var modelButtonRow = new FlowLayoutPanel { AutoSize = true, Dock = DockStyle.Fill, WrapContents = false };
        modelButtonRow.Controls.Add(_modelButton);
        AddFullRow(root, modelButtonRow);
        AddFullRow(root, _progress);
        AddFullRow(root, _modelStatus);

        AddSpacer(root, 8);
        AddFullRow(root, _startupCheck);

        var help = new Label
        {
            AutoSize = true,
            MaximumSize = new Size(420, 0),
            ForeColor = Color.DimGray,
            Text = "Hold your chosen key and speak; release to insert. Press Esc while the pill is " +
                   "showing to cancel. Everything runs on this PC — nothing is sent anywhere.",
        };
        AddSpacer(root, 8);
        AddFullRow(root, help);

        var closeButton = new Button { Text = "Close", AutoSize = true, DialogResult = DialogResult.OK };
        closeButton.Click += (_, _) => Close();
        var closeRow = new FlowLayoutPanel
        {
            AutoSize = true,
            Dock = DockStyle.Fill,
            FlowDirection = FlowDirection.RightToLeft,
            WrapContents = false,
        };
        closeRow.Controls.Add(closeButton);
        AddFullRow(root, closeRow);

        _modelCombo.SelectedIndexChanged += (_, _) => { if (!_loading) UpdateModelUi(); };
        _modelButton.Click += OnModelButtonClick;
        _holdCombo.SelectedIndexChanged += OnHoldChanged;
        _toggleCombo.SelectedIndexChanged += OnToggleChanged;
        _insertionCombo.SelectedIndexChanged += OnInsertionChanged;
        _startupCheck.CheckedChanged += OnStartupChanged;

        Controls.Add(root);
    }

    private static void AddRow(TableLayoutPanel root, string label, Control control)
    {
        int row = root.RowCount;
        root.RowCount = row + 1;
        root.Controls.Add(new Label { Text = label, AutoSize = true, Anchor = AnchorStyles.Left, Margin = new Padding(0, 8, 0, 0) }, 0, row);
        control.Margin = new Padding(0, 4, 0, 4);
        root.Controls.Add(control, 1, row);
    }

    private static void AddFullRow(TableLayoutPanel root, Control control)
    {
        int row = root.RowCount;
        root.RowCount = row + 1;
        control.Margin = new Padding(0, 4, 0, 4);
        root.Controls.Add(control, 0, row);
        root.SetColumnSpan(control, 2);
    }

    private static void AddCaption(TableLayoutPanel root, string text)
    {
        var label = new Label
        {
            Text = text,
            AutoSize = true,
            MaximumSize = new Size(430, 0),
            ForeColor = Color.DimGray,
            Font = new Font(SystemFonts.DefaultFont.FontFamily, 8f, FontStyle.Regular),
            Margin = new Padding(0, 0, 0, 4),
        };
        AddFullRow(root, label);
    }

    private static void AddHeader(TableLayoutPanel root, string text)
    {
        var label = new Label
        {
            Text = text,
            AutoSize = true,
            Font = new Font(SystemFonts.DefaultFont, FontStyle.Bold),
        };
        AddFullRow(root, label);
    }

    private static void AddSpacer(TableLayoutPanel root, int height)
    {
        int row = root.RowCount;
        root.RowCount = row + 1;
        root.Controls.Add(new Label { AutoSize = false, Height = height, Width = 1, Margin = Padding.Empty }, 0, row);
    }

    private void LoadFromSettings()
    {
        _loading = true;
        var s = _controller.Settings;

        foreach (HotkeyOption option in Enum.GetValues<HotkeyOption>())
        {
            _holdCombo.Items.Add(new OptionItem(option));
            _toggleCombo.Items.Add(new OptionItem(option));
        }
        _holdCombo.SelectedIndex = (int)s.HoldKey;
        _toggleCombo.SelectedIndex = (int)s.ToggleKey;

        _insertionCombo.Items.Add(new InsertItem(InsertionMethod.Paste, "Clipboard paste (recommended)"));
        _insertionCombo.Items.Add(new InsertItem(InsertionMethod.Type, "Typing the text out"));
        _insertionCombo.SelectedIndex = s.Insertion == InsertionMethod.Type ? 1 : 0;

        int selectedModel = 0;
        for (int i = 0; i < ModelCatalog.All.Count; i++)
        {
            _modelCombo.Items.Add(new ModelItem(ModelCatalog.All[i]));
            if (ModelCatalog.All[i].Name == s.Model) selectedModel = i;
        }
        _modelCombo.SelectedIndex = selectedModel;

        _startupCheck.Checked = StartupManager.IsEnabled();

        _loading = false;
        UpdateModelUi();
    }

    private ModelInfo? SelectedModel => (_modelCombo.SelectedItem as ModelItem)?.Info;

    private void UpdateModelUi()
    {
        var model = SelectedModel;
        if (model == null) return;
        bool downloaded = ModelDownloader.IsDownloaded(model);
        _modelButton.Text = downloaded ? "Activate this model" : "Download & activate";
        _modelStatus.Text = _controller.Whisper.StatusText;
    }

    private void OnWhisperStatusChanged()
    {
        if (IsDisposed) return;
        if (InvokeRequired)
        {
            try { BeginInvoke(new Action(OnWhisperStatusChanged)); } catch { /* closing */ }
            return;
        }
        _modelStatus.Text = _controller.Whisper.StatusText;
    }

    private async void OnModelButtonClick(object? sender, EventArgs e)
    {
        var model = SelectedModel;
        if (model == null) return;

        SetBusy(true);
        _progress.Value = 0;
        _cts = new CancellationTokenSource();
        try
        {
            var progress = new Progress<double>(f =>
            {
                try { _progress.Value = Math.Clamp((int)(f * 100), 0, 100); } catch { /* ignore */ }
            });
            await _controller.ActivateModelAsync(model, progress, _cts.Token);
            _progress.Value = 100;
        }
        catch (OperationCanceledException)
        {
            // User closed the window mid-download.
        }
        catch (Exception ex)
        {
            MessageBox.Show(this,
                "Could not download or load the model:\n\n" + ex.Message +
                "\n\nCheck your internet connection and try again.",
                "Scream", MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }
        finally
        {
            SetBusy(false);
            UpdateModelUi();
        }
    }

    private void SetBusy(bool busy)
    {
        _modelButton.Enabled = !busy;
        _modelCombo.Enabled = !busy;
        _holdCombo.Enabled = !busy;
        _toggleCombo.Enabled = !busy;
        _insertionCombo.Enabled = !busy;
        _startupCheck.Enabled = !busy;
        Cursor = busy ? Cursors.WaitCursor : Cursors.Default;
    }

    private void OnHoldChanged(object? sender, EventArgs e)
    {
        if (_loading || _holdCombo.SelectedItem is not OptionItem item) return;
        _controller.Settings.HoldKey = item.Value;
        _controller.Settings.Save();
        _controller.OnHotkeysChanged();
    }

    private void OnToggleChanged(object? sender, EventArgs e)
    {
        if (_loading || _toggleCombo.SelectedItem is not OptionItem item) return;
        _controller.Settings.ToggleKey = item.Value;
        _controller.Settings.Save();
        _controller.OnHotkeysChanged();
    }

    private void OnInsertionChanged(object? sender, EventArgs e)
    {
        if (_loading || _insertionCombo.SelectedItem is not InsertItem item) return;
        _controller.Settings.Insertion = item.Method;
        _controller.Settings.Save();
    }

    private void OnStartupChanged(object? sender, EventArgs e)
    {
        if (_loading) return;
        _controller.SetStartup(_startupCheck.Checked);
    }
}
