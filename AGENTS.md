# Image Packer — Project Context & Goals

This file documents the purpose, scope, and direction of this repository so that
future contributors (human or AI agents) can quickly understand the intent and
continue the work consistently.

## Mission

Build a maintainable, scheduled **Packer**-based image factory that produces
patched, ready-to-template virtual machine images for multiple operating systems
across multiple hypervisors / clouds.

Images are intended to be used as **templates** from which new VMs are cloned.
At clone time the following are supplied by the cloning/provisioning layer
(NOT baked into the template):

- Hostname
- Network settings (IP, DNS, gateway / DHCP)
- Active Directory domain join (Windows)
- License activation (Active Directory-based activation or KMS)

The template itself is generalized (e.g. Windows `sysprep /generalize`) so it can
be safely cloned many times.

## Target platforms (hypervisors / clouds)

- VirtualBox (local development workstation) — **first target**
- KVM / QEMU (remote server) — **second target**
- VMware vSphere — **third target**
- Microsoft Azure — later

## Target operating systems

The framework must allow multiple **versions** of each OS to live side by side.

- Windows Server — 2022, 2025, … — **first focus**
- Red Hat Enterprise Linux — 8, 9, 10, … — later
- Rocky Linux — 8, 9, … — later
- Ubuntu Server — 22.04, 24.04, … — later

## Delivery roadmap (priority order)

1. **Windows Server on VirtualBox** (local workstation) — get the end-to-end
   build working: ISO boot → unattended install → patch → generalize → export.
2. **Windows Server on remote KVM** — same build, `qemu` builder against a remote
   libvirt/KVM host.
3. **Windows Server on vSphere** — `vsphere-iso` builder against a vCenter.
4. Extend to **Linux** (RHEL, Rocky, Ubuntu) reusing the same structure.
5. Wrap builds in a **scheduled job** (e.g. CI pipeline / cron / Task Scheduler)
   so images are rebuilt regularly with the latest patches.

## Design principles

- **Versioned by OS**: each OS version is self-contained under
  `builds/<os-family>/<version>/` so e.g. Server 2016 sits alongside 2022/2025.
- **Hypervisor-agnostic builds**: each version defines a Packer `source` per
  hypervisor (VirtualBox, KVM, vSphere) and one `build` block fans out to them.
  Select a target at build time with `packer build -only=...`.
- **Shared, reusable provisioning**: OS-family provisioning scripts live in
  `scripts/<os-family>/` and are referenced by every version, avoiding copy/paste.
- **Secrets stay out of git**: passwords, license keys, vCenter creds, etc. live
  in `*.local.pkrvars.hcl` (gitignored) or environment variables, never committed.
- **Latest patches at build time**: Windows Update (and Linux equivalents) run as
  a provisioning step so each scheduled build picks up new patches automatically.
- **DHCP network configuration**: templates are built with DHCP enabled. No static
  IP is baked into the image — static addressing is applied at clone time by the
  provisioning layer.

## License activation policy

Activation is expected to occur automatically post-deployment via:

- Active Directory-based activation (preferred), or
- KMS

Templates must be volume-license compatible (GVLK) and not pre-activated.

Use a Generic Volume License Key (GVLK) in `Autounattend.xml` — not a retail or
MAK key. GVLKs are publicly documented by Microsoft for each Windows Server edition
and are safe to commit. Do **not** bake a real product key or a MAK key into the
template.

## Repository layout

See [docs/structure.md](docs/structure.md) for the full directory layout and the
rationale behind it.

## Current status

Skeleton framework in place. Windows Server 2022 / 2025 are scaffolded with a
VirtualBox source and stubs for KVM and vSphere. See
[docs/roadmap.md](docs/roadmap.md) for the live task list.
