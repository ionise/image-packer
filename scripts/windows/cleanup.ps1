<#
.SYNOPSIS
    Cleans up the image before generalization to keep the template small.
#>

$ErrorActionPreference = 'SilentlyContinue'
Write-Host 'Cleaning up image...'

# Clear Windows Update download cache.
Stop-Service -Name wuauserv -Force
Remove-Item -Path "$env:SystemRoot\SoftwareDistribution\Download\*" -Recurse -Force
Start-Service -Name wuauserv

# Component store cleanup (removes superseded update payloads).
Start-Process -FilePath 'Dism.exe' -ArgumentList '/Online','/Cleanup-Image','/StartComponentCleanup','/ResetBase' -Wait -NoNewWindow

# Temp files.
# Keep %SystemRoot%\Temp intact during build because Packer stores transient
# communicator/env scripts there between provisioner calls.
Remove-Item -Path "$env:TEMP\*" -Recurse -Force

# Clear event logs.
wevtutil el | ForEach-Object { wevtutil cl "$_" 2>$null }

# Defrag/zero free space helps the exported image compress smaller (skip on SSD-only labs).
Write-Host 'Cleanup complete.'
