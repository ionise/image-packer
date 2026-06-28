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
      source  = "github.com/hashicorp/vsphere"
      version = ">= 1.2.0"
    }
    windows-update = {
      source  = "github.com/rgl/windows-update"
      version = ">= 0.16.0"
    }
  }
}

locals {
  scripts_dir = "${path.root}/../../../scripts/windows"
  vm_name     = "windows-server-2025-${formatdate("YYYYMMDD", timestamp())}"
  autounattend_content = templatefile("${path.root}/http/Autounattend.xml.pkrtpl.hcl", {
    winrm_password = var.winrm_password
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
  shutdown_command = "powershell -ExecutionPolicy Bypass -File C:/Windows/Temp/sysprep.ps1"
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
  floppy_files = local.floppy_files
  floppy_content = {
    "Autounattend.xml" = local.autounattend_content
  }
  communicator     = "winrm"
  winrm_username   = var.winrm_username
  winrm_password   = var.winrm_password
  winrm_timeout    = "12h"
  shutdown_command = "powershell -ExecutionPolicy Bypass -File C:/Windows/Temp/sysprep.ps1"
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
  shutdown_command    = "powershell -ExecutionPolicy Bypass -File C:/Windows/Temp/sysprep.ps1"
  convert_to_template = true
}

build {
  name = "windows-2025"

  sources = [
    "source.virtualbox-iso.windows",
    "source.qemu.windows",
    "source.vsphere-iso.windows",
  ]

  provisioner "file" {
    source      = "${local.scripts_dir}/sysprep.ps1"
    destination = "C:/Windows/Temp/sysprep.ps1"
  }

  provisioner "windows-update" {
    search_criteria = "IsInstalled=0"
    filters = [
      "exclude:$_.Title -like '*Preview*'",
      "include:$true",
    ]
    restart_timeout = "2h"
  }

  provisioner "powershell" {
    environment_vars = [
      "PACKER_IMAGE_NAME=${local.vm_name}",
      "PACKER_IMAGE_ALIAS=windows-server-2025-latest",
      "PACKER_TEMPLATE_NAME=windows-2025",
      "PACKER_BUILDER_TYPE=${source.type}",
    ]
    scripts = ["${local.scripts_dir}/write-build-report.ps1"]
  }

  provisioner "powershell" {
    environment_vars = ["PACKER_BUILDER_TYPE=${source.type}"]
    scripts          = ["${local.scripts_dir}/install-guest-tools.ps1"]
  }

  provisioner "powershell" {
    scripts = ["${local.scripts_dir}/cleanup.ps1"]
  }

}
