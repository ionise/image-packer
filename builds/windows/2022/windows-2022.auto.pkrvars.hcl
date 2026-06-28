#
# Windows Server 2022 — non-secret build values (safe to commit).
# Loaded automatically by Packer because of the *.auto.pkrvars.hcl suffix.
#
# Secrets (winrm_password, vsphere_*) belong in secrets.local.pkrvars.hcl
# (gitignored) or in PKR_VAR_* environment variables.
#

# Point this at your local ISO or a download URL.
# Example local path (Windows): "file:///C:/ISOs/SERVER_EVAL_x64FRE_en-us.iso"
iso_url      = "file:///C:/LabMedia/isos/Windows/Server/2022/SERVER_EVAL_x64FRE_en-us.iso"
iso_checksum = "sha256:3E4FA6D8507B554856FC9CA6079CC402DF11A8B79344871669F0251535255325" # e.g. "sha256:<hash>" — set this for reproducible builds
windows_image_name = "Windows Server 2022 Datacenter Evaluation (Desktop Experience)"

# VM sizing
cpus      = 2
memory    = 4096
disk_size = 61440

# Show the VirtualBox console while developing the Autounattend.xml; set true for CI.
headless = false

# Use BIOS for now because EFI currently presents a blank VirtualBox console on this host.
vbox_firmware = "bios"
