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
Write-Host 'Generalizing image with sysprep...'

$sysprep = "$env:SystemRoot\System32\Sysprep\Sysprep.exe"

# Remove any stale sysprep tag from a previous run.
Remove-Item -Path "$env:SystemRoot\System32\Sysprep\Panther" -Recurse -Force -ErrorAction SilentlyContinue

& $sysprep /generalize /oobe /shutdown /quiet
