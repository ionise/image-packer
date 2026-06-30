# EFI-First Build Pattern (Windows + Linux)

This repository standardizes on an EFI-first installation path for every OS family.

## Design goals

- Consistent firmware model across Windows Server 2022, Windows Server 2025, and Linux.
- No dependency on virtual floppy media for unattended configuration.
- Deterministic boot behavior in VirtualBox by sending explicit boot input.
- Keep secrets out of git and reduce exposure of credentials during unattended install.

## Media/config delivery pattern

Use a generated config ISO for unattended files and bootstrap scripts:

- Windows: `Autounattend.xml` plus bootstrap scripts (for example `enable-winrm.ps1`) on config ISO.
- Linux: cloud-init seed ISO (`user-data`, `meta-data`) or distro-native unattended files on config ISO.

Do not rely on floppy devices. EFI behavior for floppy can vary by platform/firmware and break unattended flow.

## Boot behavior

For EFI boots where setup waits on "Press any key to boot from CD/DVD", configure explicit boot timing and key input in Packer (for example `boot_wait` + `boot_command`) so installation starts deterministically.

## Credential security over HTTP transport

If unattended assets are served via HTTP, treat them as potentially observable unless additional controls are applied.

Recommended controls:

- Prefer config ISO over HTTP for secrets whenever practical.
- If HTTP is required, bind the server to loopback or a private build network only.
- Use one-time, per-build credentials (already supported in this repo) and rotate immediately after provisioning.
- Keep unattended files and scripts out of source control when they contain real secrets.
- Avoid logging secrets in script output.
- Limit HTTP service lifetime to installation window only.
- For Linux kickstart/autoinstall, use hashed passwords and short-lived tokens rather than cleartext credentials.
- For larger environments, use HTTPS with pinned internal CA certificates and network ACLs.

## Shutdown/generalize sequencing

Run guest generalization as the final guest action, then perform explicit hypervisor shutdown via Packer. This avoids communicator race conditions during shutdown.
