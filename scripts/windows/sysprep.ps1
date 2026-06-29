<#
.SYNOPSIS
    Generalizes (sysprep) the image so it is safe to use as a clone template.

    This script is uploaded to the VM and invoked by Packer's `shutdown_command`.
    sysprep /generalize resets the machine SID, removes the computer name and other
    machine-specific state, then powers the VM off. On the next boot (i.e. when a
    new VM is cloned from the template) Windows runs OOBE, at which point your
    clone-time provisioning supplies:
        * hostname
        * network settings
        * Active Directory domain join
        * license activation

    Running sysprep from shutdown_command (rather than a normal provisioner) is the
    reliable pattern: Packer expects the WinRM connection to drop when the VM powers
    off, so the sysprep-triggered shutdown is treated as a successful build.
#>

$ErrorActionPreference = 'Stop'

Write-Host 'Preparing image for generalization...'

# 1. Pre-flight: abort if a reboot is pending.
#    Sysprep fails unpredictably when Windows Update or CBS has a pending reboot.
Write-Host 'Checking for pending reboot...'
$pendingReboot = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
if ($pendingReboot) {
    Write-Warning 'Pending reboot detected. Sysprep cannot run safely - rebooting now.'
    Restart-Computer -Force
    exit 1
}

# 2. IMPORTANT: Do not harden WinRM inside shutdown_command.
# Packer executes this script over WinRM; changing auth/listener settings here
# can break the active communicator before Sysprep starts and cause a 401 error.
# Keep hardening out of this path so the command can complete reliably.
Write-Host 'Skipping WinRM hardening during shutdown_command to preserve communicator stability.'

# 3. Clear event logs (gold image hygiene - reduces noise in downstream monitoring).
Write-Host 'Clearing event logs...'
$logs = @(wevtutil el)
foreach ($logName in $logs) {
    # Some channels (especially Analytic/Debug) cannot be cleared while enabled.
    # Do not fail sysprep for non-critical log-clear errors.
    cmd.exe /c "wevtutil cl \"$logName\" >nul 2>&1" | Out-Null
}

# 4. Generalize.
Write-Host 'Generalizing image with sysprep...'
$sysprep = "$env:SystemRoot\System32\Sysprep\Sysprep.exe"
Write-Host "Sysprep logs will be written to: $env:SystemRoot\System32\Sysprep\Panther"

& $sysprep /generalize /oobe /shutdown /quiet
