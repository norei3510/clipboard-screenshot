Option Explicit
Dim shell, fs, folder, scriptPath, exePath, needsBuild, source, exitCode
Set shell = CreateObject("WScript.Shell")
Set fs = CreateObject("Scripting.FileSystemObject")
folder = fs.GetParentFolderName(WScript.ScriptFullName)
scriptPath = fs.BuildPath(folder, "ClipboardCapture.ps1")
exePath = fs.BuildPath(folder, ".build\ClipboardCapture.exe")
needsBuild = Not fs.FileExists(exePath)
For Each source In Array("ClipboardCapture.cs", "ClipboardCapture.manifest", "ClipboardCapture.ps1")
    If Not fs.FileExists(fs.BuildPath(folder, source)) Then
        MsgBox "Missing file: " & source, vbCritical, "Clipboard Screenshot"
        WScript.Quit 1
    End If
    If Not needsBuild Then
        needsBuild = fs.GetFile(fs.BuildPath(folder, source)).DateLastModified > fs.GetFile(exePath).DateLastModified
    End If
Next
If needsBuild Then
    exitCode = shell.Run("powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File """ & scriptPath & """ -BuildOnly", 0, True)
    If exitCode <> 0 Then
        MsgBox "Screenshot build failed. Run ClipboardCapture.ps1 -BuildOnly in PowerShell for details.", vbCritical, "Clipboard Screenshot"
        WScript.Quit exitCode
    End If
End If
' A normal show state passes foreground activation to the capture application.
shell.Run """" & exePath & """", 1, False
