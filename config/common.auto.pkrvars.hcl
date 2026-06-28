#
# Common, non-secret defaults shared across all builds.
#
# NOTE: Packer loads *.auto.pkrvars.hcl only from the directory it is run in
# (the per-version build folder). This file is a central place to keep values you
# want to copy into each build, and a reference for shared conventions. To apply
# it to a build explicitly, pass it with -var-file:
#
#   packer build -var-file=../../../config/common.auto.pkrvars.hcl ...
#
# Keep SECRETS out of this file — use secrets.local.pkrvars.hcl or PKR_VAR_*.
#

# Example shared defaults (uncomment/adjust as your builds standardise):
# cpus      = 2
# memory    = 4096
# disk_size = 61440
