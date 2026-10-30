$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$tokens = $null
$parseErrors = $null
Get-ChildItem -LiteralPath $root -Filter *.ps1 | ForEach-Object {
    [Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
    if ($parseErrors) { throw ($parseErrors | Out-String) }
}
& (Join-Path $root 'ClipboardCapture.ps1') -Test
$framework = if ([Environment]::Is64BitOperatingSystem) { 'Framework64' } else { 'Framework' }
$compiler = Join-Path $env:WINDIR ('Microsoft.NET\' + $framework + '\v4.0.30319\csc.exe')
$testExe = Join-Path $root '.build\CaptureTests.exe'
& $compiler /nologo /target:exe /reference:System.Windows.Forms.dll /reference:System.Drawing.dll ('/out:' + $testExe) (Join-Path $PSScriptRoot 'CaptureTests.cs')
if ($LASTEXITCODE -ne 0) { throw 'Test compilation failed.' }
& $testExe (Join-Path $root '.build\ClipboardCapture.exe')
if ($LASTEXITCODE -ne 0) { throw 'Screenshot tests failed.' }
