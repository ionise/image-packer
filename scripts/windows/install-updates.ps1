<#
.SYNOPSIS
    Applies the latest Windows updates.

    The build normally uses the `windows-update` Packer plugin (configured in the
    *.pkr.hcl build block), which is more robust at handling reboots. This script
    is kept as a fallback / manual option and documents the intent.

    Enable it by adding it to a powershell provisioner if you prefer not to use
    the plugin.
#>

$ErrorActionPreference = 'Stop'
Write-Host 'Searching for Windows updates...'

# Use the built-in COM API so no external module download is required.
$session  = New-Object -ComObject Microsoft.Update.Session
$searcher = $session.CreateUpdateSearcher()
$result   = $searcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0")

if ($result.Updates.Count -eq 0) {
    Write-Host 'No applicable updates found.'
    return
}

Write-Host "Found $($result.Updates.Count) update(s). Downloading and installing..."

$toInstall = New-Object -ComObject Microsoft.Update.UpdateColl
foreach ($u in $result.Updates) {
    if ($u.Title -match 'Preview') { continue }
    $u.AcceptEula() | Out-Null
    $toInstall.Add($u) | Out-Null
}

$downloader = $session.CreateUpdateDownloader()
$downloader.Updates = $toInstall
$downloader.Download() | Out-Null

$installer = $session.CreateUpdateInstaller()
$installer.Updates = $toInstall
$installResult = $installer.Install()

Write-Host "Install result code: $($installResult.ResultCode)"
if ($installResult.RebootRequired) {
    Write-Host 'A reboot is required to finish installing updates.'
}
