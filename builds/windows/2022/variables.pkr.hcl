#
# Windows Server 2022 — variable declarations
#
# Non-secret values are set in *.auto.pkrvars.hcl (committed).
# Secrets are set in secrets.local.pkrvars.hcl (gitignored) or PKR_VAR_* env vars.
#

# ---- Installation media -----------------------------------------------------
variable "iso_url" {
  type        = string
  description = "URL or local path to the Windows Server 2022 ISO."
}

variable "iso_checksum" {
  type        = string
  description = "Checksum of the ISO, e.g. 'sha256:...'. Use 'none' to skip (not recommended)."
}

variable "windows_image_name" {
  type        = string
  description = "Exact /IMAGE/NAME from install.wim (e.g. Windows Server 2022 Datacenter Evaluation (Desktop Experience))."
}

variable "windows_image_index" {
  type        = string
  default     = ""
  description = "Optional /IMAGE/INDEX from install.wim. If set, this is used instead of windows_image_name."
}

# ---- VM sizing --------------------------------------------------------------
variable "cpus" {
  type        = number
  default     = 2
  description = "Number of virtual CPUs."
}

variable "memory" {
  type        = number
  default     = 4096
  description = "Memory in MB."
}

variable "disk_size" {
  type        = number
  default     = 61440
  description = "System disk size in MB."
}

variable "headless" {
  type        = bool
  default     = true
  description = "Run the build without opening a GUI console."
}

# ---- WinRM / local admin (SECRET) ------------------------------------------
variable "winrm_username" {
  type        = string
  default     = "Administrator"
  description = "Account Packer uses to connect over WinRM."
}

variable "winrm_password" {
  type        = string
  sensitive   = true
  description = "Password for the WinRM/local admin account (set in secrets file or env)."
}

# ---- VirtualBox -------------------------------------------------------------
variable "vbox_guest_os_type" {
  type        = string
  default     = "Windows2022_64"
  description = "VirtualBox guest OS type identifier."
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
  type        = string
  default     = ""
  description = "Path to the virtio-win ISO for KVM Windows builds."
}
