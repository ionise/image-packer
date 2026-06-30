<#
.SYNOPSIS
    Convenience wrapper around `packer build` for this repository.

.DESCRIPTION
    Resolves the correct build directory from the OS family and version, maps the
    chosen hypervisor to the matching Packer source, and runs init + build.

.EXAMPLE
    ./build.ps1 -Os windows -Version 2022 -Hypervisor virtualbox

.EXAMPLE
    ./build.ps1 -Os windows -Version 2025 -Hypervisor kvm -VarFile secrets.local.pkrvars.hcl

.PARAMETER Os
    OS family folder under builds/ (e.g. windows, linux/rhel).

.PARAMETER Version
    Version folder under the OS family (e.g. 2022, 2025, 9).

.PARAMETER Hypervisor
    Target hypervisor: virtualbox | kvm | vsphere.

.PARAMETER VarFile
    Optional additional -var-file (typically your gitignored secrets file).

.PARAMETER Validate
    Run `packer validate` instead of `packer build`.

.PARAMETER WinrmPassword
    Optional explicit WinRM password for Windows builds. If omitted, a random
    per-build password is generated unless -DisableEphemeralWinrmPassword is set.

.PARAMETER DisableEphemeralWinrmPassword
    For Windows builds, disables automatic random password generation and expects
    winrm_password to come from var files or environment.

.PARAMETER WindowsImageName
    Optional override for the Windows install image name (/IMAGE/NAME in
    install.wim), for example:
    "Windows Server 2022 Datacenter Evaluation (Desktop Experience)".

.PARAMETER WindowsImageIndex
    Optional override for the Windows install image index (/IMAGE/INDEX in
    install.wim). If provided, this takes precedence over WindowsImageName.

.PARAMETER OnError
    Optional pass-through to `packer build -on-error`. Use `abort` to preserve
    failed VMs for post-mortem troubleshooting.

.PARAMETER OutputRoot
    Optional base directory for build outputs. Supports absolute paths or paths
    relative to the repository root. This is passed to Packer as `output_root`.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Os,
    [Parameter(Mandatory)] [string] $Version,
    [ValidateSet('virtualbox', 'kvm', 'vsphere')]
    [string] $Hypervisor = 'virtualbox',
    [string] $VarFile,
    [switch] $Validate,
    [string] $WinrmPassword,
    [switch] $DisableEphemeralWinrmPassword,
    [string] $WindowsImageName,
    [string] $WindowsImageIndex,
    [ValidateSet('cleanup', 'abort', 'ask', 'run-cleanup-provisioner')]
    [string] $OnError,
    [string] $OutputRoot
)

$ErrorActionPreference = 'Stop'

function New-RandomPassword {
    param(
        [int]$Length = 28
    )

    $upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ'.ToCharArray()
    $lower = 'abcdefghijkmnpqrstuvwxyz'.ToCharArray()
    $digits = '23456789'.ToCharArray()
    $symbols = '!#%*+-_?@'.ToCharArray()

    $all = $upper + $lower + $digits + $symbols

    $chars = New-Object System.Collections.Generic.List[char]
    $chars.Add(($upper | Get-Random))
    $chars.Add(($lower | Get-Random))
    $chars.Add(($digits | Get-Random))
    $chars.Add(($symbols | Get-Random))

    for ($i = $chars.Count; $i -lt $Length; $i++) {
        $chars.Add(($all | Get-Random))
    }

    -join ($chars | Sort-Object { Get-Random })
}

# Map a friendly hypervisor name to its Packer source (glob matches any build name).
$sourceMap = @{
    virtualbox = '*.virtualbox-iso.windows'
    kvm        = '*.qemu.windows'
    vsphere    = '*.vsphere-iso.windows'
}

$buildDir = Join-Path $PSScriptRoot "builds/$Os/$Version"
if (-not (Test-Path $buildDir)) {
    throw "Build directory not found: $buildDir"
}

$only = $sourceMap[$Hypervisor]

Write-Host "==> Build dir : $buildDir"
Write-Host "==> Hypervisor: $Hypervisor (-only=$only)"

Push-Location $buildDir
try {
    $isWindowsBuild = $Os -eq 'windows'
    $effectiveWinrmPassword = $null

    if ($isWindowsBuild -and -not $DisableEphemeralWinrmPassword) {
        if ($WinrmPassword) {
            $effectiveWinrmPassword = $WinrmPassword
            Write-Host '==> Using explicit WinRM password supplied to build.ps1'
        }
        else {
            $effectiveWinrmPassword = New-RandomPassword
            Write-Host '==> Generated random per-build WinRM password'
        }
    }

    Write-Host '==> packer init'
    packer init .

    $args = @()
    # Always pass the shared common defaults. config/common.auto.pkrvars.hcl lives
    # at the repo root and is not auto-loaded by Packer when targeting a
    # per-version build directory.
    $commonVarFile = Join-Path $PSScriptRoot "config/common.auto.pkrvars.hcl"
    if (Test-Path $commonVarFile) {
        $args += @('-var-file', $commonVarFile)
    }
    if ($VarFile) { $args += @('-var-file', $VarFile) }
    if ($effectiveWinrmPassword) { $args += @('-var', "winrm_password=$effectiveWinrmPassword") }
    if ($WindowsImageName) { $args += @('-var', "windows_image_name=$WindowsImageName") }
    if ($WindowsImageIndex) { $args += @('-var', "windows_image_index=$WindowsImageIndex") }
    if ($OutputRoot) {
        $resolvedOutputRoot = if ([System.IO.Path]::IsPathRooted($OutputRoot)) {
            $OutputRoot
        }
        else {
            Join-Path $PSScriptRoot $OutputRoot
        }
        $args += @('-var', "output_root=$($resolvedOutputRoot -replace '\\', '/')")
    }
    $args += @("-only=$only", '.')

    if ($Validate) {
        Write-Host '==> packer validate'
        packer validate @args
    }
    else {
        Write-Host '==> packer build'
        $buildArgs = @()
        if ($OnError) {
            $buildArgs += "-on-error=$OnError"
        }
        $buildArgs += $args
        packer build @buildArgs
    }
}
finally {
    Pop-Location
}
