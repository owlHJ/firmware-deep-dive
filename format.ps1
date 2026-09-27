[CmdletBinding()]
param([switch]$Check)

$ErrorActionPreference = 'Stop'
$repoRoot = $PSScriptRoot
$tracks = @(Get-ChildItem -LiteralPath $repoRoot -Directory |
    Where-Object { $_.Name -match '^\d\d_' })
$sources = @($tracks | ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Recurse -File } |
    Where-Object {
        $_.Extension -in @('.c', '.h', '.cpp', '.hpp') -and
        $_.FullName -notmatch '[\\/]build[\\/]'
    } |
    Sort-Object FullName |
    Select-Object -ExpandProperty FullName)
if ($sources.Count -eq 0) {
    Write-Host 'No C/C++ sources in numbered tracks yet.'
    return
}

$formatter = Get-Command 'clang-format.exe' -ErrorAction SilentlyContinue
$formatterPath = if ($formatter) { $formatter.Source } else { $null }
if (-not $formatterPath) {
    foreach ($candidate in @(
        'C:\Python312\Scripts\clang-format.exe',
        'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\Llvm\bin\clang-format.exe'
    )) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $formatterPath = $candidate
            break
        }
    }
}
if (-not $formatterPath) {
    throw 'clang-format.exe was not found. Install clang-format or add it to PATH.'
}
Write-Host "Formatter: $formatterPath"
if ($Check) {
    & $formatterPath --dry-run --Werror --style=file @sources
    if ($LASTEXITCODE -ne 0) { throw 'Formatting check failed. Run format.cmd to fix it.' }
    Write-Host 'Formatting check passed.'
} else {
    & $formatterPath -i --style=file @sources
    if ($LASTEXITCODE -ne 0) { throw 'Formatting failed.' }
    Write-Host "Formatted $($sources.Count) C/C++ source file(s)."
}
