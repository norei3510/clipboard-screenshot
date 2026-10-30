#Requires AutoHotkey v2.0
#SingleInstance Force
#+F23:: {
    existing := WinExist('ahk_exe ClipboardCapture.exe')
    if existing {
        WinActivate existing
        return
    }
    exe := A_ScriptDir '\.build\ClipboardCapture.exe'
    needsBuild := !FileExist(exe)
    if !needsBuild {
        for source in ['ClipboardCapture.cs', 'ClipboardCapture.manifest', 'ClipboardCapture.ps1'] {
            if FileGetTime(A_ScriptDir '\' source, 'M') > FileGetTime(exe, 'M') {
                needsBuild := true
                break
            }
        }
    }
    if needsBuild {
        status := RunWait('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' A_ScriptDir '\ClipboardCapture.ps1" -BuildOnly', , 'Hide')
        if status != 0 {
            MsgBox 'Screenshot build failed. Run ClipboardCapture.ps1 -BuildOnly for details.'
            return
        }
    }
    Run '"' exe '"', , , &pid
    ; Activate the actual overlay rather than the intermediate hidden launcher.
    if WinWait('ahk_pid ' pid, , 5)
        WinActivate 'ahk_pid ' pid
}
