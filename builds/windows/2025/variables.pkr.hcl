#
# Windows Server 2025 — variable declarations. See builds/windows/2022 for notes.
#

# ---- Installation media -----------------------------------------------------
variable "iso_url" {
  type        = string
  description = "URL or local path to the Windows Server 2025 ISO."
}

variable "iso_checksum" {
  type        = string
  description = "Checksum of the ISO, e.g. 'sha256:...'. Use 'none' to skip."
}

variable "windows_image_name" {
  type        = string
  description = "Exact /IMAGE/NAME from install.wim (e.g. Windows Server 2025 Datacenter Evaluation (Desktop Experience))."
}

variable "windows_image_index" {
  type        = string
  default     = ""
  description = "Optional /IMAGE/INDEX from install.wim. If set, this is used instead of windows_image_name."
}

# ---- VM sizing --------------------------------------------------------------
variable "cpus" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 4096
}

variable "disk_size" {
  type    = number
  default = 61440
}

variable "headless" {
  type    = bool
  default = true
}

# ---- WinRM / local admin (SECRET) ------------------------------------------
variable "winrm_username" {
  type    = string
  default = "Administrator"
}

variable "winrm_password" {
  type      = string
  sensitive = true
}

# ---- VirtualBox -------------------------------------------------------------
variable "vbox_guest_os_type" {
  type        = string
  default     = "Windows2022_64"
  description = "VirtualBox guest OS type; use Windows2025_64 if your VirtualBox version supports it."
}

variable "vbox_firmware" {
  type        = string
  default     = "efi"
  description = "VirtualBox firmware mode: efi or bios."
}

# ---- vSphere (only needed when building the vsphere-iso source) -------------
variable "vsphere_guest_os_type" {
  type    = string
  default = "windows2019srvNext_64Guest"
}

variable "vsphere_server" {
  type    = string
  default = ""
}

variable "vsphere_username" {
  type    = string
  default = ""
}

variable "vsphere_password" {
  type      = string
  default   = ""
  sensitive = true
}

variable "vsphere_insecure" {
  type    = bool
  default = true
}

variable "vsphere_datacenter" {
  type    = string
  default = ""
}

variable "vsphere_cluster" {
  type    = string
  default = ""
}

variable "vsphere_datastore" {
  type    = string
  default = ""
}

variable "vsphere_folder" {
  type    = string
  default = ""
}

variable "vsphere_network" {
  type    = string
  default = ""
}

variable "vsphere_iso_path" {
  type    = string
  default = ""
}

# ---- KVM / QEMU -------------------------------------------------------------
variable "virtio_iso" {
  type    = string
  default = ""
}
