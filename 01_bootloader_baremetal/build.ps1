[CmdletBinding()]
param(
    [string]$ToolchainBin
)

$ErrorActionPreference = 'Stop'
$sourceDir = $PSScriptRoot
$buildDir = Join-Path $sourceDir 'build'
$toolchainFile = Join-Path $sourceDir 'cmake\arm-none-eabi.cmake'

function Find-Executable {
    param([string]$Name)
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    return $null
}

$cmake = Find-Executable 'cmake.exe'
$ninja = Find-Executable 'ninja.exe'
if (-not $cmake) { throw 'CMake was not found in PATH. Install CMake, then open a new PowerShell window.' }
if (-not $ninja) { throw 'Ninja was not found in PATH. Install Ninja, then open a new PowerShell window.' }

if ($ToolchainBin) {
    $ToolchainBin = (Resolve-Path -LiteralPath $ToolchainBin -ErrorAction Stop).Path
} elseif (-not (Find-Executable 'arm-none-eabi-gcc.exe')) {
    # The bundled compiler is usable without launching CubeIDE or generating code.
    $cubeRoot = 'C:\ST'
    if (Test-Path -LiteralPath $cubeRoot) {
        $candidate = Get-ChildItem -LiteralPath $cubeRoot -Filter 'arm-none-eabi-gcc.exe' -File -Recurse -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending | Select-Object -First 1
        if ($candidate) { $ToolchainBin = $candidate.DirectoryName }
    }
}

if ($ToolchainBin) {
    foreach ($name in @('arm-none-eabi-gcc.exe', 'arm-none-eabi-objcopy.exe', 'arm-none-eabi-size.exe')) {
        if (-not (Test-Path -LiteralPath (Join-Path $ToolchainBin $name) -PathType Leaf)) {
            throw "Missing $name in $ToolchainBin"
        }
    }
    Write-Host "Arm GNU tools: $ToolchainBin"
} elseif (-not (Find-Executable 'arm-none-eabi-gcc.exe')) {
    throw 'Arm GNU Toolchain was not found. Pass -ToolchainBin "C:\path\to\tools\bin".'
}

# A configured build tree keeps the compiler selected during its first configure.
if (Test-Path -LiteralPath (Join-Path $buildDir 'CMakeCache.txt')) {
    $cachedCompiler = Select-String -LiteralPath (Join-Path $buildDir 'CMakeCache.txt') -Pattern '^ARM_GCC:FILEPATH=' -ErrorAction SilentlyContinue
    if ($cachedCompiler -and $ToolchainBin) {
        $selectedCompiler = (Join-Path $ToolchainBin 'arm-none-eabi-gcc.exe').Replace('\', '/')
        $cachedPath = ($cachedCompiler.Line -split '=', 2)[1].Replace('\', '/')
        if ($cachedPath -and ($cachedPath -ne $selectedCompiler)) {
            throw "This build directory uses a different compiler: $cachedPath. Remove only '$buildDir' and rerun."
        }
    }
}

$arguments = @('-S', $sourceDir, '-B', $buildDir, '-G', 'Ninja', "-DCMAKE_MAKE_PROGRAM=$ninja")
if (-not (Test-Path -LiteralPath (Join-Path $buildDir 'CMakeCache.txt'))) {
    $arguments += "-DCMAKE_TOOLCHAIN_FILE=$toolchainFile"
}
if ($ToolchainBin) { $arguments += "-DARM_TOOLCHAIN_BIN=$ToolchainBin" }

& $cmake @arguments
if ($LASTEXITCODE -ne 0) { throw "CMake configuration failed (exit $LASTEXITCODE)." }
& $cmake --build $buildDir
if ($LASTEXITCODE -ne 0) { throw "Build failed (exit $LASTEXITCODE)." }

$binPath = Join-Path $buildDir 'startup_uart2.bin'
$hexPath = Join-Path $buildDir 'startup_uart2.hex'
foreach ($path in @($binPath, $hexPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Expected output missing: $path" }
}

Write-Host ''
Write-Host "Flash file: $binPath"
Write-Host 'Flash Loader address for BIN: 0x08000000'
Write-Host "HEX file:   $hexPath"
Write-Host 'Build succeeded. Board execution still requires Flash Verify and UART testing.'
