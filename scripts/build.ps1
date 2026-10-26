[CmdletBinding()]
param(
    [ValidateSet('riscv32-elf', 'riscv64-elf', 'riscv32-glibc', 'riscv64-glibc')]
    [string]$Variant = 'riscv64-elf',

    [string]$Release = $(if ($env:RELEASE) { $env:RELEASE } else { '2026.08.27' }),

    [string]$ImageTag = $env:IMAGE_TAG,

    [ValidateSet('wslc', 'docker')]
    [string]$ContainerCli = 'wslc'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectDir = Split-Path -Parent $PSScriptRoot
$archive = Join-Path $projectDir "downloads/$Release/$Variant-ubuntu-24.04-gcc.tar.xz"
if (-not (Test-Path -LiteralPath $archive -PathType Leaf)) {
    throw "Toolchain archive not found: $archive"
}

$cli = Get-Command $ContainerCli -CommandType Application -ErrorAction Stop
if (-not $ImageTag) {
    $ImageTag = "riscv-toolchain:${Release}-${Variant}"
}

$buildArgs = @('build', '--progress', 'plain')
if ($ContainerCli -eq 'docker') {
    $buildArgs += @('--platform', 'linux/amd64')
} elseif ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() -ne 'X64') {
    throw 'These archives require an x86-64 host when building with wslc.'
}
$buildArgs += @(
    '--build-arg', "RELEASE=$Release",
    '--build-arg', "TOOLCHAIN=$Variant",
    '--tag', $ImageTag,
    $projectDir
)

& $cli.Source @buildArgs
if ($LASTEXITCODE -ne 0) {
    throw "Image build failed with exit code ${LASTEXITCODE}: $ImageTag"
}
