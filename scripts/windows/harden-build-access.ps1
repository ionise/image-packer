<#
.SYNOPSIS
    Removes build-time WinRM and autologon settings before sysprep.

.DESCRIPTION
    The image build enables permissive WinRM (basic + unencrypted) and temporary
    autologon to allow unattended setup and provisioning. This script removes or
    tightens those settings so the resulting template does not keep build-time
    remote access posture.
#>

$ErrorActionPreference = 'SilentlyContinue'

Write-Host 'Hardening build-time access settings...'

# Disable insecure WinRM authentication options used only during build.
winrm set winrm/config/service/auth '@{Basic="false"}' | Out-Null
winrm set winrm/config/service '@{AllowUnencrypted="false"}' | Out-Null
winrm set winrm/config/client/auth '@{Basic="false"}' | Out-Null

# Remove HTTP listener used for Packer build connectivity.
winrm delete winrm/config/Listener?Address=*+Transport=HTTP | Out-Null

# Remove the explicit firewall rule created by enable-winrm.ps1.
Remove-NetFirewallRule -Name 'WinRM-HTTP-In-Packer' | Out-Null

# Stop WinRM; keep startup as Manual so clone-time automation can enable as needed.
Stop-Service -Name WinRM -Force | Out-Null
Set-Service -Name WinRM -StartupType Manual | Out-Null

# Remove autologon values from Winlogon.
$winlogon = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
Set-ItemProperty -Path $winlogon -Name AutoAdminLogon -Value '0' -Type String | Out-Null
Remove-ItemProperty -Path $winlogon -Name DefaultUserName -ErrorAction SilentlyContinue | Out-Null
Remove-ItemProperty -Path $winlogon -Name DefaultPassword -ErrorAction SilentlyContinue | Out-Null
Remove-ItemProperty -Path $winlogon -Name DefaultDomainName -ErrorAction SilentlyContinue | Out-Null

Write-Host 'Build-time access hardening complete.'
