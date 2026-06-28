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

# 2. Apply final build-time access hardening before Sysprep.
#    harden-build-access.ps1 disables insecure WinRM auth and removes the build
#    account autologon. Calling it here (rather than as a Packer provisioner)
#    ensures Packer retains WinRM access all the way up to shutdown_command.
if (Test-Path 'C:\Windows\Temp\harden-build-access.ps1') {
    Write-Host 'Applying build-time access hardening...'
    & 'C:\Windows\Temp\harden-build-access.ps1'
}

# 3. Clear event logs (gold image hygiene - reduces noise in downstream monitoring).
Write-Host 'Clearing event logs...'
wevtutil el | ForEach-Object { wevtutil cl "$_" 2>$null }

# 4. Generalize.
Write-Host 'Generalizing image with sysprep...'
$sysprep = "$env:SystemRoot\System32\Sysprep\Sysprep.exe"
Write-Host "Sysprep logs will be written to: $env:SystemRoot\System32\Sysprep\Panther"

& $sysprep /generalize /oobe /shutdown /quiet
