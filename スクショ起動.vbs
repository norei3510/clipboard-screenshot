Set shell = CreateObject("WScript.Shell")
Set fs = CreateObject("Scripting.FileSystemObject")
scriptPath = fs.BuildPath(fs.GetParentFolderName(WScript.ScriptFullName), "ClipboardCapture.ps1")
shell.Run "powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File """ & scriptPath & """", 0, False
