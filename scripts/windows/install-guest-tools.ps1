<#
.SYNOPSIS
    Installs hypervisor guest tools appropriate to the builder type.

    Packer sets PACKER_BUILDER_TYPE; we branch on it:
      virtualbox-iso -> VirtualBox Guest Additions (ISO attached by Packer)
      qemu           -> virtio guest tools / drivers
      vsphere-iso    -> VMware Tools

    Stubs are provided for KVM and vSphere - flesh these out in Phase 2 / Phase 3.
#>

$ErrorActionPreference = 'Stop'
$builder = $env:PACKER_BUILDER_TYPE
Write-Host "Installing guest tools for builder: $builder"

switch -Wildcard ($builder) {
    'virtualbox*' {
        # Packer attaches the Guest Additions ISO (guest_additions_mode = "attach").
        $drive = (Get-Volume | Where-Object { $_.FileSystemLabel -like 'VBox_GAs*' }).DriveLetter
        if (-not $drive) { $drive = 'E' }
        $installer = "${drive}:\VBoxWindowsAdditions.exe"
        if (Test-Path $installer) {
            # Pre-trust the Oracle certificate so the install is silent.
            $certDir = "${drive}:\cert"
            if (Test-Path $certDir) {
                Get-ChildItem "$certDir\*.cer" | ForEach-Object {
                    & "$certDir\VBoxCertUtil.exe" add-trusted-publisher $_.FullName --root $_.FullName
                }
            }
            Start-Process -FilePath $installer -ArgumentList '/S' -Wait
            Write-Host 'VirtualBox Guest Additions installed.'
        } else {
            Write-Warning "Guest Additions installer not found at $installer"
        }
    }
    'qemu*' {
        # TODO (Phase 2): install virtio-win guest tools from the virtio ISO.
        Write-Host 'KVM/QEMU guest tools step is a stub - see docs/roadmap.md Phase 2.'
    }
    'vsphere*' {
        # TODO (Phase 3): install VMware Tools.
        Write-Host 'vSphere VMware Tools step is a stub - see docs/roadmap.md Phase 3.'
    }
    default {
        Write-Warning "Unknown builder '$builder' - skipping guest tools."
    }
}
