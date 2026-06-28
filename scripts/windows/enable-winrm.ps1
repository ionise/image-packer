<#
.SYNOPSIS
    Enables and configures WinRM so Packer can connect to the VM.

    Run automatically by Autounattend.xml on first logon (from virtual floppy or CD).
    A drive-discovery loop in the answer file locates this script regardless of the
    drive letter assigned by the hypervisor, making the bootstrap hypervisor-agnostic.

    Configures HTTP WinRM with Basic auth for the build session only. The template
    is later hardened before sysprep by scripts/windows/harden-build-access.ps1.
#>

$ErrorActionPreference = 'Stop'

# Log the source drive so builds are easier to diagnose across hypervisors.
Write-Host "WinRM bootstrap launched from $PSScriptRoot"

# Idempotency guard — safe to run multiple times (FirstLogonCommands may fire
# more than once across reboots, and the loop may find multiple matches).
if (Get-NetFirewallRule -Name 'WinRM-HTTP-In-Packer' -ErrorAction SilentlyContinue) {
    Write-Host 'WinRM already configured for Packer. Skipping.'
    exit 0
}

Write-Host 'Configuring WinRM for Packer...'

# Ensure the WinRM service is running and set to start automatically.
# quickconfig is intentionally omitted — every setting is applied explicitly
# below, which keeps the build deterministic and auditable.
Set-Service -Name WinRM -StartupType Automatic
Start-Service -Name WinRM

# Allow the auth/transport Packer uses during the build.
winrm set winrm/config/service/auth '@{Basic="true"}' | Out-Null
winrm set winrm/config/service '@{AllowUnencrypted="true"}' | Out-Null
winrm set winrm/config/client/auth '@{Basic="true"}' | Out-Null
winrm set winrm/config '@{MaxTimeoutms="1800000"}' | Out-Null

# Open the firewall for WinRM HTTP (5985).
New-NetFirewallRule -DisplayName 'WinRM HTTP-In (Packer)' -Name 'WinRM-HTTP-In-Packer' `
    -Protocol TCP -LocalPort 5985 -Action Allow -Direction Inbound `
    -ErrorAction SilentlyContinue | Out-Null

# Make sure the HTTP listener exists.
$listener = winrm enumerate winrm/config/listener 2>$null
if (-not ($listener | Select-String 'Transport = HTTP')) {
    Write-Host 'Creating WinRM HTTP listener...'
    winrm create winrm/config/listener?Address=*+Transport=HTTP | Out-Null
} else {
    Write-Host 'WinRM HTTP listener already exists.'
}

Restart-Service -Name WinRM

# Wait until WinRM is actually accepting connections before returning.
# Packer is sensitive to "listener exists but not yet ready" races.
Write-Host 'Waiting for WinRM readiness...'
$maxAttempts = 30
$attempt     = 0
$ready       = $false
do {
    Start-Sleep -Seconds 2
    $attempt++
    try {
        Test-WSMan -ErrorAction Stop | Out-Null
        $ready = $true
    } catch {
        $ready = $false
    }
} while (-not $ready -and $attempt -lt $maxAttempts)

if (-not $ready) {
    throw 'WinRM did not become ready after 60 seconds'
}

Write-Host 'WinRM configured and ready.'
