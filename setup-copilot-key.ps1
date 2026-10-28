$ErrorActionPreference = 'Stop'
$ahk = Join-Path $env:ProgramFiles 'AutoHotkey\v2\AutoHotkey64.exe'
if (-not (Test-Path -LiteralPath $ahk)) {
    throw 'AutoHotkey v2 が見つかりません。AutoHotkey v2 をインストールしてください。'
}
$script = Join-Path $PSScriptRoot 'copilot-hotkey.ahk'
$launcher = Join-Path $PSScriptRoot 'スクショ起動.vbs'
if (-not (Test-Path -LiteralPath $launcher)) { throw 'スクショ起動.vbs が見つかりません。' }
$check = Start-Process -FilePath $ahk -ArgumentList @('/validate', ('"' + $script + '"')) -Wait -PassThru -WindowStyle Hidden
if ($check.ExitCode -ne 0) { throw 'AutoHotkey のスクリプトを検証できませんでした。' }
$startup = [Environment]::GetFolderPath('Startup')
$linkPath = Join-Path $startup 'ClipboardScreenshot.lnk'
$shell = New-Object -ComObject WScript.Shell
if (Test-Path -LiteralPath $linkPath) {
    $existing = $shell.CreateShortcut($linkPath)
    if ($existing.TargetPath -ne $ahk -or $existing.Arguments -ne ('"' + $script + '"')) {
        throw "別の設定が存在するため上書きしません: $linkPath"
    }
}
$link = $shell.CreateShortcut($linkPath)
$link.TargetPath = $ahk
$link.Arguments = '"' + $script + '"'
$link.WorkingDirectory = $PSScriptRoot
$link.Save()
Start-Process -FilePath $ahk -ArgumentList ('"' + $script + '"') -WindowStyle Hidden
Write-Host '設定しました。別のアプリが同じキーを使用している場合は、その設定を解除してください。'
