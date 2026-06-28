<#
.SYNOPSIS
    Removes build-time WinRM and autologon settings before sysprep.

.DESCRIPTION
    The image build enables permissive WinRM (basic + unencrypted) and temporary
    autologon to allow unattended setup and provisioning. This script removes or
    tightens those settings so the resulting template does not keep build-time
    remote access posture.

    This script is called from sysprep.ps1 immediately before Sysprep runs, NOT
    as a standalone Packer provisioner. Running it here ensures Packer retains
    WinRM access all the way up to shutdown_command.
#>

$ErrorActionPreference = 'Stop'

Write-Host 'Hardening build-time access settings...'

# Disable insecure WinRM authentication options used only during build.
# Wrap each winrm CLI call: if WinRM is partially configured the command can
# fail, and we don't want to abort on a config that may already be locked down.
Write-Host 'Disabling insecure WinRM authentication...'
try { winrm set winrm/config/service/auth '@{Basic="false"}' | Out-Null } catch {}
try { winrm set winrm/config/service '@{AllowUnencrypted="false"}' | Out-Null } catch {}
try { winrm set winrm/config/client/auth '@{Basic="false"}' | Out-Null } catch {}

# Remove HTTP listener used for Packer build connectivity.
Write-Host 'Removing WinRM HTTP listener...'
try { winrm delete winrm/config/Listener?Address=*+Transport=HTTP | Out-Null } catch {}

# Remove the explicit firewall rule created by enable-winrm.ps1.
# -ErrorAction SilentlyContinue: rule may not exist if the build skipped that step.
Write-Host 'Removing Packer WinRM firewall rule...'
Remove-NetFirewallRule -Name 'WinRM-HTTP-In-Packer' -ErrorAction SilentlyContinue

# Stop WinRM; keep startup as Manual so clone-time automation can enable as needed.
Write-Host 'Stopping WinRM service...'
Stop-Service -Name WinRM -Force
Set-Service -Name WinRM -StartupType Manual

# Remove autologon values from Winlogon.
Write-Host 'Removing autologon registry values...'
$winlogon = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
Set-ItemProperty -Path $winlogon -Name AutoAdminLogon -Value '0' -Type String
Remove-ItemProperty -Path $winlogon -Name DefaultUserName    -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $winlogon -Name DefaultPassword    -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $winlogon -Name DefaultDomainName  -ErrorAction SilentlyContinue

# Clear the built-in Administrator password so it does not persist in the template.
# Sysprep /generalize resets machine identity but does not remove the local account
# password set during installation. A blank password here ensures the template has no
# residual build credential — clone-time automation must set a new password on first boot.
Write-Host 'Clearing Administrator password...'
$admin = [ADSI]'WinNT://./Administrator,user'
$admin.SetPassword('')
$admin.SetInfo()

Write-Host 'Build-time access hardening complete.'
