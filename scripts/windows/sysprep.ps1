<#
.SYNOPSIS
    Generalizes (sysprep) the image so it is safe to use as a clone template.

    This script is uploaded to the VM and can run sysprep in either mode:
        * shutdown: /generalize /oobe /shutdown /quiet
        * quit:     /generalize /oobe /quit /quiet
#>

param(
    [ValidateSet('shutdown', 'quit')]
    [string]$Mode = 'shutdown'
)

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

# 2. IMPORTANT: Do not harden WinRM in this script.
# This script runs over WinRM; changing auth/listener settings here can break the
# active communicator before Sysprep starts.
Write-Host 'Skipping WinRM hardening during Sysprep run to preserve communicator stability.'

# 3. Clear event logs (gold image hygiene - reduces noise in downstream monitoring).
Write-Host 'Clearing event logs...'
$logs = @(wevtutil el)
foreach ($logName in $logs) {
    # Some channels (especially Analytic/Debug) cannot be cleared while enabled.
    # Do not fail sysprep for non-critical log-clear errors.
    cmd.exe /c "wevtutil cl \"$logName\" >nul 2>&1" | Out-Null
}

# 4. Generalize.
Write-Host ("Generalizing image with sysprep (mode: {0})..." -f $Mode)
$sysprep = "$env:SystemRoot\System32\Sysprep\Sysprep.exe"
Write-Host "Sysprep logs will be written to: $env:SystemRoot\System32\Sysprep\Panther"

# Launch sysprep detached so the WinRM command can return cleanly.
$modeArg = if ($Mode -eq 'quit') { '/quit' } else { '/shutdown' }
$proc = Start-Process -FilePath $sysprep -ArgumentList '/generalize', '/oobe', $modeArg, '/quiet' -PassThru
if (-not $proc) {
    throw 'Failed to start Sysprep process.'
}

Write-Host ("Sysprep started (PID {0}) with {1}." -f $proc.Id, $modeArg)
exit 0
