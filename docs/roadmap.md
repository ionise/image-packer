# Roadmap & task list

Status legend: `[ ]` todo · `[~]` in progress · `[x]` done

## Phase 0 — Framework skeleton
- [x] Document goals (`AGENTS.md`)
- [x] Define directory structure (`docs/structure.md`)
- [x] Scaffold Windows Server 2022 + 2025 build directories
- [x] Shared Windows provisioning scripts
- [x] Build helper (`build.ps1`)

## Phase 1 — Windows Server on VirtualBox (local)
- [ ] Obtain Windows Server 2022 evaluation ISO; set `iso_url` + `iso_checksum`
- [ ] Validate `Autounattend.xml` performs a full unattended install
- [ ] Confirm WinRM comes up so Packer can connect
- [ ] Install VirtualBox Guest Additions
- [ ] Run Windows Update to apply latest patches
- [ ] Sysprep / generalize the image
- [ ] Export to OVA and confirm it imports & boots
- [ ] Validate clone supplies hostname / network / domain join / activation

## Phase 2 — Windows Server on remote KVM
- [ ] Add/verify `qemu` source block + plugin
- [ ] Configure remote libvirt/KVM connection
- [ ] virtio drivers in `Autounattend.xml`
- [ ] End-to-end build and export (qcow2)

## Phase 3 — Windows Server on vSphere
- [ ] Add/verify `vsphere-iso` source block + plugin
- [ ] vCenter credentials via secrets var-file / env
- [ ] Content Library template publish

## Phase 4 — Linux
- [ ] RHEL 8/9/10 (kickstart)
- [ ] Rocky 8/9 (kickstart)
- [ ] Ubuntu 22.04/24.04 (cloud-init / autoinstall)

## Phase 5 — Automation
- [ ] Parameterised scheduled job (CI pipeline / Task Scheduler / cron)
- [ ] Patch-cadence rebuilds
- [ ] Image versioning / naming convention & retention
