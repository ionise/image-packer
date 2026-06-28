#
# Windows Server 2025 — Packer build definition.
# Mirrors builds/windows/2022. See that folder's comments for full details.
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
  scripts_dir = "${path.root}/../../../scripts/windows"
  vm_name     = "windows-server-2025-${formatdate("YYYYMMDD-hhmm", timestamp())}"
  autounattend_content = templatefile("${path.root}/http/Autounattend.xml.pkrtpl.hcl", {
    winrm_password     = var.winrm_password
    windows_image_name = var.windows_image_name
    windows_image_index = var.windows_image_index
    firmware_mode      = var.vbox_firmware
  })
  floppy_files = [
    "${local.scripts_dir}/enable-winrm.ps1",
  ]
}

source "virtualbox-iso" "windows" {
  vm_name              = local.vm_name
  guest_os_type        = var.vbox_guest_os_type
  iso_url              = var.iso_url
  iso_checksum         = var.iso_checksum
  cpus                 = var.cpus
  memory               = var.memory
  disk_size            = var.disk_size
  hard_drive_interface = "sata"
  firmware             = var.vbox_firmware
  headless             = var.headless
  floppy_files         = local.floppy_files
  floppy_content = {
    "Autounattend.xml" = local.autounattend_content
  }
  guest_additions_mode = "attach"
  communicator         = "winrm"
  winrm_username       = var.winrm_username
  winrm_password       = var.winrm_password
  winrm_timeout        = "12h"
  winrm_use_ssl        = false
  winrm_insecure       = true
  vboxmanage = [
    ["modifyvm", "{{.Name}}", "--firmware", var.vbox_firmware],
    ["modifyvm", "{{.Name}}", "--graphicscontroller", "vboxsvga"],
    ["modifyvm", "{{.Name}}", "--vram", "128"],
    ["modifyvm", "{{.Name}}", "--accelerate3d", "off"],
    ["modifyvm", "{{.Name}}", "--boot1", "dvd"],
    ["modifyvm", "{{.Name}}", "--nat-localhostreachable1", "on"],
  ]
  shutdown_command = "powershell -ExecutionPolicy Bypass -File C:/ProgramData/Packer/sysprep.ps1"
  shutdown_timeout = "30m"
  output_directory = "${path.root}/output/virtualbox"
  format           = "ova"
}

source "qemu" "windows" {
  vm_name      = local.vm_name
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum
  cpus         = var.cpus
  memory       = var.memory
  disk_size    = "${var.disk_size}M"
  format       = "qcow2"
  accelerator  = "kvm"
  headless     = var.headless

  # Windows needs virtio drivers injected during install for disk/net.
  # Supply the virtio-win ISO via var.virtio_iso and reference its drivers
  # from the Autounattend template. See docs/roadmap.md Phase 2.
  floppy_files = local.floppy_files
  floppy_content = {
    "Autounattend.xml" = local.autounattend_content
  }

  communicator     = "winrm"
  winrm_username   = var.winrm_username
  winrm_password   = var.winrm_password
  winrm_timeout    = "12h"
  shutdown_command = "powershell -ExecutionPolicy Bypass -File C:/ProgramData/Packer/sysprep.ps1"
  output_directory = "${path.root}/output/qemu"
}

source "vsphere-iso" "windows" {
  vm_name             = local.vm_name
  guest_os_type       = var.vsphere_guest_os_type
  vcenter_server      = var.vsphere_server
  username            = var.vsphere_username
  password            = var.vsphere_password
  insecure_connection = var.vsphere_insecure
  datacenter          = var.vsphere_datacenter
  cluster             = var.vsphere_cluster
  datastore           = var.vsphere_datastore
  folder              = var.vsphere_folder
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
  communicator        = "winrm"
  winrm_username      = var.winrm_username
  winrm_password      = var.winrm_password
  winrm_timeout       = "12h"
  shutdown_command    = "powershell -ExecutionPolicy Bypass -File C:/ProgramData/Packer/sysprep.ps1"
  # Phase 3A: convert_to_template = true targets a vSphere VM template in a folder.
  # Phase 3B: switch to the plugin's content_library_destination block and set
  # convert_to_template = false — the vSphere plugin does not support Content Library
  # import from a VM that was already converted to a template.
  # Document the chosen model in docs/vsphere.md before finalising Phase 3.
  convert_to_template = true
}

build {
  name = "windows-2025"

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
    scripts          = ["${local.scripts_dir}/install-guest-tools.ps1"]
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
      "PACKER_IMAGE_ALIAS=windows-server-2025-latest",
      "PACKER_TEMPLATE_NAME=windows-2025",
      "PACKER_BUILDER_TYPE=${source.type}",
    ]
    scripts = ["${local.scripts_dir}/write-build-report.ps1"]
  }

  # 5. Clean up to keep the template small.
  provisioner "powershell" {
    scripts = ["${local.scripts_dir}/cleanup.ps1"]
  }

  # NOTE: harden-build-access is NOT run as a standalone provisioner here.
  # It is called from inside sysprep.ps1 immediately before Sysprep so that
  # Packer retains WinRM access until the shutdown_command is invoked.
}
