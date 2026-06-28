# Shared Linux provisioning scripts (placeholder)

Reusable scripts for Linux image builds will live here (Phase 4), e.g.:

- `install-updates.sh`   — apply latest patches (dnf/apt)
- `install-guest-tools.sh` — open-vm-tools / virtio / VBox Guest Additions
- `cleanup.sh`           — clear logs, package caches, machine-id
- `generalize.sh`        — reset cloud-init / machine-id so clones get fresh identity

See [docs/roadmap.md](../../docs/roadmap.md) Phase 4.
