param([switch]$Test)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$source = @"
using System;
using System.Drawing;
using System.Windows.Forms;
using System.Runtime.InteropServices;

public sealed class ClipboardCapture : Form {
    [DllImport("user32.dll")] private static extern bool SetProcessDPIAware();
    private readonly Bitmap screen;
    private Point start, current;
    private bool dragging;

    private ClipboardCapture(Bitmap image, Rectangle bounds) {
        screen = image;
        FormBorderStyle = FormBorderStyle.None;
        StartPosition = FormStartPosition.Manual;
        Bounds = bounds;
        TopMost = true;
        ShowInTaskbar = false;
        DoubleBuffered = true;
        Cursor = Cursors.Cross;
        KeyPreview = true;
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
        using (var font = new Font("Segoe UI", 12))
        using (var brush = new SolidBrush(Color.White))
            e.Graphics.DrawString("Drag to select  /  Esc to cancel", font, brush, 12, 12);
    }
    private Rectangle Selection() {
        return Rectangle.FromLTRB(Math.Min(start.X,current.X), Math.Min(start.Y,current.Y), Math.Max(start.X,current.X), Math.Max(start.Y,current.Y));
    }
    protected override void OnMouseDown(MouseEventArgs e) {
        if (e.Button != MouseButtons.Left) return;
        start = current = e.Location; dragging = true; Capture = true; Invalidate();
    }
    protected override void OnMouseMove(MouseEventArgs e) {
        if (!dragging) return;
        current = new Point(Math.Max(0, Math.Min(ClientSize.Width, e.X)), Math.Max(0, Math.Min(ClientSize.Height, e.Y)));
        Invalidate();
    }
    protected override void OnMouseUp(MouseEventArgs e) {
        if (!dragging || e.Button != MouseButtons.Left) return;
        current = new Point(Math.Max(0, Math.Min(ClientSize.Width, e.X)), Math.Max(0, Math.Min(ClientSize.Height, e.Y)));
        Rectangle rect = Selection(); dragging = false;
        if (rect.Width > 0 && rect.Height > 0) {
            using (Bitmap result = screen.Clone(rect, screen.PixelFormat)) Clipboard.SetImage(result);
            Close();
        } else Invalidate();
    }
    protected override void OnKeyDown(KeyEventArgs e) { if (e.KeyCode == Keys.Escape) Close(); }
    public static void Run() {
        SetProcessDPIAware();
        Rectangle bounds = SystemInformation.VirtualScreen;
        using (Bitmap image = new Bitmap(bounds.Width, bounds.Height)) {
            using (Graphics g = Graphics.FromImage(image)) g.CopyFromScreen(bounds.Location, Point.Empty, bounds.Size);
            using (var window = new ClipboardCapture(image, bounds)) Application.Run(window);
        }
    }
}
"@
try {
    Add-Type -TypeDefinition $source -ReferencedAssemblies System.Windows.Forms, System.Drawing
    if (-not $Test) { [ClipboardCapture]::Run() }
} catch {
    if ($Test) { throw }
    [System.Windows.Forms.MessageBox]::Show("Screenshot failed: $($_.Exception.Message)", 'Clipboard capture') | Out-Null
}
