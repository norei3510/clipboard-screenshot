param([switch]$Test, [switch]$BuildOnly)
$ErrorActionPreference = 'Stop'

# Compile once; normal launches use the cached executable without PowerShell.
$source = Join-Path $PSScriptRoot 'ClipboardCapture.cs'
$manifest = Join-Path $PSScriptRoot 'ClipboardCapture.manifest'
$buildDir = Join-Path $PSScriptRoot '.build'
$exe = Join-Path $buildDir 'ClipboardCapture.exe'
$framework = if ([Environment]::Is64BitOperatingSystem) { 'Framework64' } else { 'Framework' }
$compiler = Join-Path $env:WINDIR ('Microsoft.NET\' + $framework + '\v4.0.30319\csc.exe')
$hash = [Security.Cryptography.SHA256]::Create()
try { $buildId = [BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($PSScriptRoot))).Replace('-', '') } finally { $hash.Dispose() }
$buildLock = New-Object Threading.Mutex($false, ('Local\ClipboardScreenshotBuild-' + $buildId))
$locked = $false
try {
    try { $locked = $buildLock.WaitOne(30000) } catch [Threading.AbandonedMutexException] { $locked = $true }
    if (-not $locked) { throw 'Timed out waiting for the screenshot build.' }
    $needsBuild = -not (Test-Path -LiteralPath $exe)
    if (-not $needsBuild) {
        $builtAt = (Get-Item -LiteralPath $exe).LastWriteTimeUtc
        $needsBuild = @(@($source, $manifest, $PSCommandPath) | Where-Object { (Get-Item -LiteralPath $_).LastWriteTimeUtc -gt $builtAt }).Count -gt 0
    }
    if ($needsBuild) {
        New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
        $temporaryExe = Join-Path $buildDir ('ClipboardCapture-' + [Guid]::NewGuid().ToString('N') + '.exe')
        try {
            & $compiler /nologo /target:winexe /optimize+ /reference:System.Windows.Forms.dll /reference:System.Drawing.dll "/win32manifest:$manifest" "/out:$temporaryExe" $source
            if ($LASTEXITCODE -ne 0) { throw 'Screenshot compilation failed.' }
            Move-Item -LiteralPath $temporaryExe -Destination $exe -Force
        } finally {
            if (Test-Path -LiteralPath $temporaryExe) { Remove-Item -LiteralPath $temporaryExe }
        }
    }
} finally {
    if ($locked) { $buildLock.ReleaseMutex() }
    $buildLock.Dispose()
}
if (-not ($Test -or $BuildOnly)) { Start-Process -FilePath $exe -WindowStyle Normal }
