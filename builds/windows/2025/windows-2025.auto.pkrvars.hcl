#
# Windows Server 2025 — non-secret build values (safe to commit).
# Loaded automatically by Packer because of the *.auto.pkrvars.hcl suffix.
#
# Secrets (winrm_password, vsphere_*) belong in secrets.local.pkrvars.hcl
# (gitignored) or in PKR_VAR_* environment variables.
#

# Point this at your local ISO or a download URL.
# Example local path (Windows): "file:///C:/LabMedia/isos/Windows/Server/2025/SERVER_EVAL_x64FRE_en-us.iso"
iso_url      = "file:///C:/LabMedia/isos/Windows/Server/2025/26100.32230.260111-0550.lt_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso"
iso_checksum = "sha256:7B052573BA7894C9924E3E87BA732CCD354D18CB75A883EFA9B900EA125BFD51"
windows_image_name = "Windows Server 2025 Datacenter Evaluation (Desktop Experience)"

# VM sizing
cpus      = 2
memory    = 4096
disk_size = 61440

# Show the VirtualBox console while developing the Autounattend.xml; set true for CI.
headless = false

# EFI is the default for Server 2025. Switch to bios if your host requires it.
vbox_firmware = "efi"
