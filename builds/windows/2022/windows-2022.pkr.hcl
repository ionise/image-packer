#
# Windows Server 2022 — Packer build definition
#
# Defines one `source` per hypervisor (VirtualBox, KVM/QEMU, vSphere) and a single
# `build` block that fans out to them. Select a target at build time with -only,
# e.g.  packer build -only="virtualbox-iso.windows" .
#
# Shared provisioning scripts live in scripts/windows and are referenced relative
# to this directory.
#

packer {
  required_plugins {
    virtualbox = {
      source  = "github.com/hashicorp/virtualbox"
      version = ">= 1.0.0"
    }
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = ">= 1.0.0"
    }
    vsphere = {
      source  = "github.com/vmware/vsphere"
      version = ">= 2.0.0"
    }
    windows-update = {
      source  = "github.com/rgl/windows-update"
      version = ">= 0.16.0"
    }
  }
}

locals {
  # Path to the OS-family provisioning scripts shared by every Windows version.
  scripts_dir = "${path.root}/../../../scripts/windows"

  # Optional external output root; default stays in this version folder.
  output_root = var.output_root != "" ? replace(var.output_root, "\\", "/") : "${path.root}/output"

  # Friendly name baked into the produced template / artifact.
  vm_name = "windows-server-2022-${formatdate("YYYYMMDD-hhmm", timestamp())}"

  # Render Autounattend.xml from a template so secrets are injected at build time
  # from var.winrm_password (not committed in git).
  autounattend_content = templatefile("${path.root}/http/Autounattend.xml.pkrtpl.hcl", {
    winrm_password     = var.winrm_password
    windows_image_name = var.windows_image_name
    windows_image_index = var.windows_image_index
    firmware_mode      = var.vbox_firmware
  })

  # Bootstrap scripts presented to the installer on floppy.
  floppy_files = [
    "${local.scripts_dir}/enable-winrm.ps1",
  ]
}

# ---------------------------------------------------------------------------
# VirtualBox (local development workstation) — FIRST TARGET
# ---------------------------------------------------------------------------
source "virtualbox-iso" "windows" {
  vm_name       = local.vm_name
  guest_os_type = var.vbox_guest_os_type
  iso_url       = var.iso_url
  iso_checksum  = var.iso_checksum

  cpus                 = var.cpus
  memory               = var.memory
  disk_size            = var.disk_size
  hard_drive_interface = "sata"
  firmware             = var.vbox_firmware

  headless     = var.headless
  floppy_files = local.floppy_files
  floppy_content = {
    "Autounattend.xml" = local.autounattend_content
  }
  guest_additions_mode = "attach"

  # WinRM is brought up by enable-winrm.ps1 during the unattended install.
  communicator   = "winrm"
  winrm_username = var.winrm_username
  winrm_password = var.winrm_password
  winrm_timeout  = "12h"
  winrm_use_ssl  = false
  winrm_insecure = true

  vboxmanage = [
    ["modifyvm", "{{.Name}}", "--firmware", var.vbox_firmware],
    ["modifyvm", "{{.Name}}", "--graphicscontroller", "vboxsvga"],
    ["modifyvm", "{{.Name}}", "--vram", "128"],
    ["modifyvm", "{{.Name}}", "--accelerate3d", "off"],
    ["modifyvm", "{{.Name}}", "--boot1", "dvd"],
    ["modifyvm", "{{.Name}}", "--nat-localhostreachable1", "on"],
  ]

  # Sysprep runs as the final provisioner in /quit mode; this is only the
  # explicit OS shutdown Packer waits on afterward.
  shutdown_command = "shutdown /s /t 5 /f /d p:4:1 /c \"Packer final shutdown\""
  shutdown_timeout = "30m"

  output_directory = "${local.output_root}/virtualbox/${local.vm_name}"
  format           = "ova"
}

# ---------------------------------------------------------------------------
# KVM / QEMU (remote server) — SECOND TARGET (stub: tune for your environment)
# ---------------------------------------------------------------------------
source "qemu" "windows" {
  vm_name      = local.vm_name
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  cpus        = var.cpus
  memory      = var.memory
  disk_size   = "${var.disk_size}M"
  format      = "qcow2"
  accelerator = "kvm"
  headless    = var.headless

  # Windows needs virtio drivers injected during install for disk/net.
  # Supply the virtio-win ISO via var.virtio_iso and reference its drivers
  # from the Autounattend template. See docs/roadmap.md Phase 2.
  floppy_files = local.floppy_files
  floppy_content = {
    "Autounattend.xml" = local.autounattend_content
  }

  communicator   = "winrm"
  winrm_username = var.winrm_username
  winrm_password = var.winrm_password
  winrm_timeout  = "12h"

  shutdown_command = "shutdown /s /t 5 /f /d p:4:1 /c \"Packer final shutdown\""
  output_directory = "${local.output_root}/qemu/${local.vm_name}"
}

# ---------------------------------------------------------------------------
# VMware vSphere — THIRD TARGET (stub: tune for your vCenter)
# ---------------------------------------------------------------------------
source "vsphere-iso" "windows" {
  vm_name       = local.vm_name
  guest_os_type = var.vsphere_guest_os_type

  # vCenter connection — supply via secrets.local.pkrvars.hcl or PKR_VAR_*.
  vcenter_server      = var.vsphere_server
  username            = var.vsphere_username
  password            = var.vsphere_password
  insecure_connection = var.vsphere_insecure

  datacenter = var.vsphere_datacenter
  cluster    = var.vsphere_cluster
  datastore  = var.vsphere_datastore
  folder     = var.vsphere_folder
  network_adapters {
    network      = var.vsphere_network
    network_card = "vmxnet3"
  }

  CPUs = var.cpus
  RAM  = var.memory
  storage {
    disk_size             = var.disk_size
    disk_thin_provisioned = true
  }

  iso_paths    = [var.vsphere_iso_path]
  floppy_files = local.floppy_files
  floppy_content = {
    "Autounattend.xml" = local.autounattend_content
  }

  communicator   = "winrm"
  winrm_username = var.winrm_username
  winrm_password = var.winrm_password
  winrm_timeout  = "12h"

  shutdown_command    = "shutdown /s /t 5 /f /d p:4:1 /c \"Packer final shutdown\""
  # Phase 3A: convert_to_template = true targets a vSphere VM template in a folder.
  # Phase 3B: switch to the plugin's content_library_destination block and set
  # convert_to_template = false — the vSphere plugin does not support Content Library
  # import from a VM that was already converted to a template.
  # Document the chosen model in docs/vsphere.md before finalising Phase 3.
  convert_to_template = true
}

# ---------------------------------------------------------------------------
# Build — shared provisioning across every selected hypervisor
# ---------------------------------------------------------------------------
build {
  name = "windows-2022"

  sources = [
    "source.virtualbox-iso.windows",
    "source.qemu.windows",
    "source.vsphere-iso.windows",
  ]

  # 0. Create a stable staging directory for build control scripts.
  provisioner "powershell" {
    inline = [
      "New-Item -Path 'C:/ProgramData/Packer' -ItemType Directory -Force | Out-Null",
    ]
  }

  # 1. Upload the sysprep script and hardening script; the per-source
  #    shutdown_command invokes sysprep.ps1, which calls harden-build-access.ps1
  #    immediately before running Sysprep. Uploading both here (before any
  #    reboots) ensures they are present regardless of update restart cycles.
  provisioner "file" {
    source      = "${local.scripts_dir}/sysprep.ps1"
    destination = "C:/ProgramData/Packer/sysprep.ps1"
  }

  provisioner "file" {
    source      = "${local.scripts_dir}/harden-build-access.ps1"
    destination = "C:/ProgramData/Packer/harden-build-access.ps1"
  }

  # 2. Install hypervisor guest tools first — better drivers, time sync, and
  #    device behaviour before the machine goes through update/reboot cycles.
  provisioner "powershell" {
    environment_vars = ["PACKER_BUILDER_TYPE=${source.type}"]
    scripts = [
      "${local.scripts_dir}/install-guest-tools.ps1",
    ]
  }

  # 3. Apply the latest Windows updates (the whole point of scheduled rebuilds).
  provisioner "windows-update" {
    search_criteria = "IsInstalled=0"
    filters = [
      "exclude:$_.Title -like '*Preview*'",
      "include:$true",
    ]
    restart_timeout = "2h"
  }

  # 4. Capture build timestamp and installed patch inventory.
  provisioner "powershell" {
    environment_vars = [
      "PACKER_IMAGE_NAME=${local.vm_name}",
      "PACKER_IMAGE_ALIAS=windows-server-2022-latest",
      "PACKER_TEMPLATE_NAME=windows-2022",
      "PACKER_BUILDER_TYPE=${source.type}",
    ]
    scripts = [
      "${local.scripts_dir}/write-build-report.ps1",
    ]
  }

  # 5. Clean up to keep the template small.
  provisioner "powershell" {
    scripts = [
      "${local.scripts_dir}/cleanup.ps1",
    ]
  }

  # 6. Generalize without shutting down so communicator remains stable.
  # Packer then performs the source shutdown_command above.
  provisioner "powershell" {
    inline = [
      "powershell -NoProfile -ExecutionPolicy Bypass -File C:/ProgramData/Packer/sysprep.ps1 -Mode quit",
    ]
  }

  # NOTE: harden-build-access is NOT run as a standalone provisioner here.
  # It is called from inside sysprep.ps1 immediately before Sysprep so that
  # Packer retains WinRM access until final shutdown_command is invoked.
}
