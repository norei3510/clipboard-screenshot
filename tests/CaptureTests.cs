using System;
using System.Drawing;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Windows.Forms;
class CaptureTests {
    [DllImport("user32.dll")] static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    static int checks;
    static void Check(bool ok, string message) { if (!ok) throw new Exception(message); checks++; Console.WriteLine("PASS " + message); }
    static void Mouse(Form form, string method, int x, int y, MouseButtons button) {
        form.GetType().GetMethod(method, BindingFlags.Instance | BindingFlags.NonPublic).Invoke(form, new object[] { new MouseEventArgs(button, 1, x, y, 0) });
    }
    static Form Create(Type type, Bitmap image, Rectangle bounds) {
        return (Form)Activator.CreateInstance(type, BindingFlags.Instance | BindingFlags.NonPublic, null, new object[] { image, bounds }, null);
    }
    [STAThread] static int Main(string[] args) {
        try {
            SetThreadDpiAwarenessContext(new IntPtr(-4));
            Type type = Assembly.LoadFrom(args[0]).GetType("ClipboardCapture");
            Rectangle desktop = SystemInformation.VirtualScreen;
            using (var image = new Bitmap(desktop.Width, desktop.Height))
            using (Graphics g = Graphics.FromImage(image)) {
                g.Clear(Color.CornflowerBlue);
                using (Form form = Create(type, image, desktop)) {
                    form.Show(); Application.DoEvents();
                    Check(form.Bounds == desktop, "overlay covers physical desktop");
                    Check(form.TopMost, "overlay stays above normal windows");
                    Check(GetForegroundWindow() == form.Handle, "overlay receives foreground focus");
                    Mouse(form, "OnMouseDown", 80, 70, MouseButtons.Left);
                    Mouse(form, "OnMouseMove", 20, 10, MouseButtons.None);
                    Mouse(form, "OnMouseUp", 20, 10, MouseButtons.Left);
                    Application.DoEvents();
                    using (var copied = (Bitmap)Clipboard.GetImage()) {
                        Check(copied.Width == 60 && copied.Height == 60, "reverse drag copies exact pixel dimensions");
                        Check(copied.GetPixel(30, 30).ToArgb() == Color.CornflowerBlue.ToArgb(), "copied pixels match source");
                    }
                    Check(form.IsDisposed, "successful selection closes overlay");
                }
                using (Form form = Create(type, image, desktop)) {
                    form.Show(); Application.DoEvents();
                    Mouse(form, "OnMouseDown", 50, 50, MouseButtons.Left);
                    Mouse(form, "OnMouseUp", 50, 50, MouseButtons.Left);
                    Check(!form.IsDisposed, "zero-size click keeps selection open");
                    Mouse(form, "OnMouseDown", 20, 10, MouseButtons.Left);
                    Mouse(form, "OnMouseUp", desktop.Width + 100, desktop.Height + 100, MouseButtons.Left);
                    using (var copied = Clipboard.GetImage())
                        Check(copied.Width == desktop.Width - 20 && copied.Height == desktop.Height - 10, "selection clamps to bitmap edges");
                }
                using (Form form = Create(type, image, desktop)) {
                    form.Show(); Application.DoEvents();
                    type.GetMethod("OnKeyDown", BindingFlags.Instance | BindingFlags.NonPublic).Invoke(form, new object[] { new KeyEventArgs(Keys.Escape) });
                    Check(form.IsDisposed, "Escape closes overlay");
                }
            }
            Rectangle wide = new Rectangle(-1920, -200, 5760, 1400);
            using (var image = new Bitmap(wide.Width, wide.Height))
            using (Form form = Create(type, image, wide)) {
                form.Show(); Application.DoEvents();
                Check(form.Bounds == wide, "negative-origin three-monitor bounds avoid Form size limits");
                form.Close();
            }
            Console.WriteLine(checks + " checks passed"); return 0;
        } catch(Exception error) { Console.Error.WriteLine(error); return 1; }
    }
}
