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
Set-Service -Name WinRM -StartupType Automatic
Start-Service -Name WinRM

# Basic quick-config (creates the default HTTP listener).
winrm quickconfig -quiet

# Allow the auth/transport Packer uses during the build.
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/client/auth '@{Basic="true"}'
winrm set winrm/config '@{MaxTimeoutms="1800000"}'

# Open the firewall for WinRM HTTP (5985).
New-NetFirewallRule -DisplayName 'WinRM HTTP-In (Packer)' -Name 'WinRM-HTTP-In-Packer' `
    -Protocol TCP -LocalPort 5985 -Action Allow -Direction Inbound -ErrorAction SilentlyContinue

# Make sure the listener exists.
$listener = winrm enumerate winrm/config/listener
if ($listener -notmatch 'Transport = HTTP') {
    winrm create winrm/config/listener?Address=*+Transport=HTTP
}

Restart-Service -Name WinRM
Write-Host 'WinRM configured.'
