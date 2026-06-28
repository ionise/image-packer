#
# Secrets template — DO NOT put real secrets in this file.
#
# Copy this file to "secrets.local.pkrvars.hcl" (which is gitignored) and fill in
# real values, then pass it on the command line:
#
#   packer build -var-file=secrets.local.pkrvars.hcl -only="virtualbox-iso.windows" .
#
# Alternatively, set environment variables instead of a file, e.g.:
#   $env:PKR_VAR_winrm_password = "..."
#

winrm_password = "ChangeMe-Str0ngP@ss!"

# vSphere (only needed for the vsphere-iso source)
# vsphere_server     = "vcenter.example.com"
# vsphere_username   = "packer@vsphere.local"
# vsphere_password   = "..."
# vsphere_datacenter = "DC1"
# vsphere_cluster    = "Cluster1"
# vsphere_datastore  = "datastore1"
# vsphere_folder     = "Templates"
# vsphere_network    = "VM Network"
# vsphere_iso_path   = "[datastore1] ISOs/windows-server-2025.iso"
