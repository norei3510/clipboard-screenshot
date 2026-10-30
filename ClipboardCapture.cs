using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

public sealed class ClipboardCapture : Form {
    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool SetWindowPos(IntPtr window, IntPtr after, int x, int y, int width, int height, uint flags);
    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr window);
    [DllImport("user32.dll")]
    private static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);

    private readonly Bitmap screen;
    private readonly Rectangle desktopBounds;
    private Point start, current;
    private bool dragging;

    [StructLayout(LayoutKind.Sequential)]
    private struct MinMaxInfo {
        public Point Reserved, MaxSize, MaxPosition, MinTrackSize, MaxTrackSize;
    }

    private ClipboardCapture(Bitmap image, Rectangle bounds) {
        screen = image;
        desktopBounds = bounds;
        Text = "Clipboard Screenshot";
        AutoScaleMode = AutoScaleMode.None;
        FormBorderStyle = FormBorderStyle.None;
        StartPosition = FormStartPosition.Manual;
        Bounds = bounds;
        TopMost = true;
        ShowInTaskbar = false;
        DoubleBuffered = true;
        Cursor = Cursors.Cross;
        KeyPreview = true;
    }

    protected override void OnShown(EventArgs e) {
        base.OnShown(e);
        // Bypass Form.Bounds' maximum tracking size and cover the whole desktop.
        if (!SetWindowPos(Handle, new IntPtr(-1), desktopBounds.X, desktopBounds.Y,
                desktopBounds.Width, desktopBounds.Height, 0x0040))
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        SetForegroundWindow(Handle);
        Activate();
        Focus();
    }

    protected override void WndProc(ref Message m) {
        // The overlay already covers the desktop in physical pixels. A DPI
        // change must not resize it to the suggested bounds of one monitor.
        if (m.Msg == 0x02E0) { m.Result = IntPtr.Zero; return; }
        base.WndProc(ref m);
        if (m.Msg == 0x0024 && desktopBounds.Width > 0) {
            var limits = (MinMaxInfo)Marshal.PtrToStructure(m.LParam, typeof(MinMaxInfo));
            limits.MaxSize = new Point(desktopBounds.Width, desktopBounds.Height);
            limits.MaxTrackSize = limits.MaxSize;
            Marshal.StructureToPtr(limits, m.LParam, false);
        }
    }

    protected override void OnPaint(PaintEventArgs e) {
        e.Graphics.DrawImageUnscaled(screen, 0, 0);
        using (var shade = new SolidBrush(Color.FromArgb(90, Color.Black)))
            e.Graphics.FillRectangle(shade, ClientRectangle);
        if (dragging) {
            Rectangle rect = Selection();
            if (rect.Width > 0 && rect.Height > 0) {
                e.Graphics.DrawImage(screen, rect, rect, GraphicsUnit.Pixel);
                using (var pen = new Pen(Color.DeepSkyBlue, 2)) e.Graphics.DrawRectangle(pen, rect);
            }
        }
        Rectangle monitor = Screen.FromPoint(Cursor.Position).Bounds;
        using (var font = new Font("Segoe UI", 12))
        using (var brush = new SolidBrush(Color.White))
            e.Graphics.DrawString("Drag to select  /  Esc to cancel", font, brush,
                monitor.Left - desktopBounds.Left + 12, monitor.Top - desktopBounds.Top + 12);
    }

    private Point Clamp(Point point) {
        return new Point(Math.Max(0, Math.Min(screen.Width, point.X)),
            Math.Max(0, Math.Min(screen.Height, point.Y)));
    }

    private Rectangle Selection() {
        return Rectangle.FromLTRB(Math.Min(start.X, current.X), Math.Min(start.Y, current.Y),
            Math.Max(start.X, current.X), Math.Max(start.Y, current.Y));
    }

    protected override void OnMouseDown(MouseEventArgs e) {
        if (e.Button != MouseButtons.Left) return;
        start = current = Clamp(e.Location);
        dragging = true;
        Capture = true;
        Invalidate();
    }

    protected override void OnMouseMove(MouseEventArgs e) {
        if (!dragging) return;
        current = Clamp(e.Location);
        Invalidate();
    }

    protected override void OnMouseUp(MouseEventArgs e) {
        if (!dragging || e.Button != MouseButtons.Left) return;
        current = Clamp(e.Location);
        Rectangle rect = Selection();
        dragging = false;
        Capture = false;
        if (rect.Width == 0 || rect.Height == 0) { Invalidate(); return; }
        try {
            using (Bitmap result = screen.Clone(rect, screen.PixelFormat)) {
                // Keep the image after exit; retry a temporarily busy clipboard.
                var data = new DataObject();
                data.SetData(DataFormats.Bitmap, true, result);
                Clipboard.SetDataObject(data, true, 10, 50);
            }
            Close();
        } catch (ExternalException) {
            MessageBox.Show(this, "Clipboard is busy. Please select the area again.", Text);
            Invalidate();
        }
    }

    protected override void OnKeyDown(KeyEventArgs e) {
        if (e.KeyCode == Keys.Escape) Close();
        base.OnKeyDown(e);
    }

    [STAThread]
    public static void Main() {
        bool created;
        using (var instance = new Mutex(true, "Local\\ClipboardScreenshotCapture", out created)) {
            if (!created) return;
            try {
                try { SetThreadDpiAwarenessContext(new IntPtr(-4)); }
                catch (EntryPointNotFoundException) { /* Manifest handles older Windows. */ }
                Application.SetUnhandledExceptionMode(UnhandledExceptionMode.ThrowException);
                Rectangle bounds = SystemInformation.VirtualScreen;
                using (Bitmap image = new Bitmap(bounds.Width, bounds.Height)) {
                    using (Graphics g = Graphics.FromImage(image))
                        g.CopyFromScreen(bounds.Location, Point.Empty, bounds.Size);
                    using (var window = new ClipboardCapture(image, bounds)) Application.Run(window);
                }
            } catch (Exception error) {
                MessageBox.Show("Screenshot failed: " + error.Message, "Clipboard Screenshot");
            } finally { instance.ReleaseMutex(); }
        }
    }
}
