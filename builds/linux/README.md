# Linux builds (future work — Phase 4)

Linux image builds are planned but not yet implemented. The structure mirrors the
Windows side: one folder per distro family, then per version.

Planned layout:

```
builds/linux/
├── rhel/{8,9,10}/      # kickstart-based unattended install
├── rocky/{8,9}/        # kickstart-based unattended install
└── ubuntu/{2204,2404}/ # cloud-init / Subiquity autoinstall
```

Each version folder will contain, by analogy with the Windows builds:

- `<distro>-<version>.pkr.hcl` — `required_plugins`, a `source` per hypervisor
  (`virtualbox-iso`, `qemu`, `vsphere-iso`), and a `build` block.
- `variables.pkr.hcl` and `*.auto.pkrvars.hcl`.
- `http/` — `ks.cfg` (RHEL/Rocky) or `user-data` + `meta-data` (Ubuntu).

Shared provisioning scripts go in `scripts/linux/`. The communicator will be `ssh`
instead of `winrm`, and generalization uses cloud-init reset / `sys-unconfig`
rather than sysprep.

See [docs/roadmap.md](../../docs/roadmap.md) Phase 4.
