# Image Packer

Create virtual machine template images using HashiCorp Packer.

## Development Environment on Windows 11

Set up VirtualBox first, then install Packer on your Windows 11 workstation.

## Install VirtualBox

Use one of the following installation options.

### Option A: Install with WinGet (Recommended)

Run in PowerShell (non-admin is usually fine):

	winget install Oracle.VirtualBox

### Option B: Manual Installation

1. Go to https://www.virtualbox.org/wiki/Downloads
2. Download the Windows hosts installer
3. Run the installer and keep default options unless you have specific network requirements
4. Reboot if prompted

Optional: install the VirtualBox Extension Pack from the same downloads page if your workflow needs USB 2.0/3.0, disk encryption, or NVMe support.

## Verify VirtualBox Installation

Run:

	VBoxManage --version

If you see a version number, VirtualBox is installed correctly.

If the command is not found, close and reopen PowerShell, then try again.

## Install Packer

You can install Packer using one of these options.

### Option A: Install with WinGet (Recommended)

Run in PowerShell (non-admin is fine):

	winget install HashiCorp.Packer

This will:

- Install the Packer binary
- Install plugin support
- Add Packer to PATH automatically

### Option B: Manual Installation

1. Go to https://developer.hashicorp.com/packer/downloads
2. Download the Windows AMD64 ZIP
3. Extract packer.exe
4. Place it in a folder such as C:\Tools\Packer\
5. Add that folder to your PATH

## Install the Packer VirtualBox Plugin

Packer uses plugins for builders and provisioners. For VirtualBox builds, install the VirtualBox plugin.

### Recommended: Let `packer init` Install Plugins from Template

If your template includes a `required_plugins` block for VirtualBox, run:

	packer init .

Example `required_plugins` block:

	packer {
	  required_plugins {
	    virtualbox = {
	      source  = "github.com/hashicorp/virtualbox"
	      version = ">= 1.0.0"
	    }
	  }
	}

### Manual Plugin Installation

Run:

	packer plugins install github.com/hashicorp/virtualbox

### Verify Plugin Installation

Run:

	packer plugins installed

You should see `github.com/hashicorp/virtualbox` in the output.

## Verify Installation

Run:

	packer version

Expected output is similar to:

	1.10.x

If you see a command not found error, PATH is not configured correctly.

## Project goals & context

This repository is an image factory for building patched VM templates for multiple
operating systems across multiple hypervisors. Read [AGENTS.md](AGENTS.md) for the
full mission, scope, and design principles, and [docs/roadmap.md](docs/roadmap.md)
for the live task list.

Highlights:

- First focus: **Windows Server on VirtualBox** (this workstation), then remote
  **KVM**, then **vSphere**; later RHEL, Rocky, and Ubuntu.
- Templates are generalized (sysprep) so clones supply their own hostname,
  network, AD domain join, and activation at clone time.
- Builds run the latest **Windows Update** so scheduled rebuilds stay patched.

## Repository structure

See [docs/structure.md](docs/structure.md) for the full layout and rationale.
In short, each OS version is self-contained under `builds/<os-family>/<version>/`,
shares provisioning scripts in `scripts/<os-family>/`, and defines one `source`
per hypervisor so a single build can target VirtualBox, KVM, or vSphere.

## ISO media layout (recommended)

Store ISO files outside this git repository in a central media path, then reference
them from each build's `iso_url` setting.

Recommended root paths:

- `D:/LabMedia/isos` (preferred when available)
- `C:/ISOs` (simple single-disk option)

Suggested directory structure:

```
D:/LabMedia/isos/
├── windows/
│   └── server/
│       ├── 2022/
│       │   ├── SERVER_EVAL_x64FRE_en-us.iso
│       │   └── SHA256SUMS.txt
│       └── 2025/
│           ├── SERVER_2025_EVAL_x64FRE_en-us.iso
│           └── SHA256SUMS.txt
└── linux/
	├── rhel/
	│   └── 9/
	│       ├── rhel-9.x-x86_64-dvd.iso
	│       └── SHA256SUMS.txt
	├── rocky/
	│   └── 9/
	│       ├── Rocky-9.x-x86_64-dvd.iso
	│       └── SHA256SUMS.txt
	└── ubuntu/
		└── 24.04/
			├── ubuntu-24.04-live-server-amd64.iso
			└── SHA256SUMS
```

Example `iso_url` values (file URI format):

- `file:///D:/LabMedia/isos/windows/server/2022/SERVER_EVAL_x64FRE_en-us.iso`
- `file:///D:/LabMedia/isos/windows/server/2025/SERVER_2025_EVAL_x64FRE_en-us.iso`

Use real `sha256:` checksums in `iso_checksum` instead of `none` whenever possible.

## Building an image

A worked example is provided for Windows Server 2022 and 2025.

1. Provide an ISO: edit `builds/windows/2022/windows-2022.auto.pkrvars.hcl` and set
   `iso_url` (and ideally `iso_checksum`).

### WindowsImageName (important)

`windows_image_name` is ISO-specific. The exact value can differ between evaluation,
retail, Desktop Experience, Core, and different media revisions.

If the value does not exactly match an image name in `install.wim`, Windows Setup may
show errors such as unable to find software license terms or invalid installation
sources.

To find the correct value for your ISO:

1. Mount the ISO or identify its drive letter during setup (for example `D:`).
2. Run:

	dism /Get-WimInfo /WimFile:D:\sources\install.wim

3. Copy the exact `Name` value you want (for example
	`Windows Server 2022 Datacenter Evaluation (Desktop Experience)`).
4. Set that exact string in `windows_image_name` in
	`builds/windows/2022/windows-2022.auto.pkrvars.hcl`, or pass it at build time:

	./build.ps1 -Os windows -Version 2022 -Hypervisor virtualbox -WindowsImageName "Windows Server 2022 Datacenter Evaluation (Desktop Experience)"

2. Provide secrets: copy `builds/windows/2022/secrets.example.pkrvars.hcl` to
   `builds/windows/2022/secrets.local.pkrvars.hcl` (gitignored) and set
	`winrm_password`. This is injected into `Autounattend.xml` at build time from
	`http/Autounattend.xml.pkrtpl.hcl`.
3. Build with the helper script (from the repo root):

	./build.ps1 -Os windows -Version 2022 -Hypervisor virtualbox -VarFile secrets.local.pkrvars.hcl

   Or validate first:

	./build.ps1 -Os windows -Version 2022 -Hypervisor virtualbox -Validate

   Or call Packer directly:

	cd builds/windows/2022
	packer init .
	packer build -var-file=secrets.local.pkrvars.hcl -only="virtualbox-iso.windows" .

The output OVA is written to `builds/windows/2022/output/virtualbox/`.

### Per-build random WinRM password (recommended)

`build.ps1` now generates a random `winrm_password` for each Windows build run and
passes it to Packer with `-var`.

This means the build password can be random per run and does not need to be stored
in source control or in a persistent secrets file.

Example:

	./build.ps1 -Os windows -Version 2022 -Hypervisor virtualbox

Optional controls:

- Provide your own password for a run:

	./build.ps1 -Os windows -Version 2022 -Hypervisor virtualbox -WinrmPassword "<temporary-password>"

- Disable random generation and rely on var files/env:

	./build.ps1 -Os windows -Version 2022 -Hypervisor virtualbox -DisableEphemeralWinrmPassword -VarFile secrets.local.pkrvars.hcl

During provisioning, `scripts/windows/harden-build-access.ps1` removes build-time
WinRM posture and autologon before sysprep.

The build also runs `scripts/windows/write-build-report.ps1`, which records build
timestamp and installed hotfix inventory inside the VM at:

- `C:\Windows\Temp\packer-build-report\build-report.json`
- `C:\Windows\Temp\packer-build-report\hotfixes.csv`
- `C:\Windows\Temp\packer-build-report\build-report.txt`

It also writes image identity metadata to:

- `C:\ProgramData\ImageMetadata\image-info.json`

This metadata includes image name/alias, template name, build UTC timestamp,
builder type, computer name, and OS version/build.

A summary and hotfix list are emitted to stdout and are therefore captured in the
Packer host log when `PACKER_LOG` is enabled.

### Clone-time local Administrator password

Set a new local Administrator password at clone/deploy time (separate from build-time
WinRM secret) using your platform provisioning workflow:

- vSphere: Guest Customization Specification / customization manager.
- Azure: VM deployment parameters or post-deploy extension.
- KVM/QEMU: first-boot provisioning (cloud-init/Ansible/PowerShell remoting).

This gives you separation between image factory access and production VM credentials.

### Password lifecycle recommendations

Use two distinct credentials with different lifecycles:

1. Build password (ephemeral):
	 generated randomly at build start, used only for Packer WinRM communication,
	 then removed by `scripts/windows/harden-build-access.ps1` before sysprep.
2. Production local Administrator password (persistent/managed):
	 injected at clone/deploy time by the platform automation and managed through
	 your server lifecycle controls.

Recommended storage and lifecycle policy for production credentials:

- Store in a central secrets system (for example Azure Key Vault, HashiCorp Vault,
	CyberArk, or another enterprise PAM/secrets platform), not in repo files.
- Scope access by environment and role (least privilege), and audit all reads.
- Rotate on a schedule and on incident response events.
- For AD-joined servers, prefer Windows LAPS as the long-term local admin password
	authority and automatic rotation mechanism.
- Treat local admin as break-glass where possible; prefer named admin identities
	and JIT/JEA style access for day-to-day operations.

Minimal clone-time flow:

1. Clone VM from template.
2. Inject hostname/network/domain join settings.
3. Retrieve or generate production local admin credential from secret manager.
4. Set the local Administrator password during guest customization/first boot.
5. Register/rotate credential in lifecycle system (LAPS or PAM).

### Targeting other hypervisors

Switch `-Hypervisor` to `kvm` or `vsphere` (these are scaffolded as stubs — see the
roadmap). The corresponding Packer sources are `qemu.windows` and
`vsphere-iso.windows`.

