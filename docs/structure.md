# Repository structure

```
image-packer/
├── AGENTS.md                     # Project context & goals (read this first)
├── README.md                     # Setup / tooling instructions
├── build.ps1                     # Helper to invoke a build for an OS/version/hypervisor
├── .gitignore
│
├── docs/
│   ├── structure.md              # This file
│   └── roadmap.md                # Live task list / progress
│
├── config/
│   └── common.auto.pkrvars.hcl   # Defaults shared by all builds (non-secret)
│
├── builds/                       # One folder per OS family, then per version
│   ├── windows/
│   │   ├── 2022/                 # Worked example
│   │   │   ├── windows-2022.pkr.hcl       # required_plugins + sources + build
│   │   │   ├── variables.pkr.hcl          # variable declarations
│   │   │   ├── windows-2022.auto.pkrvars.hcl  # non-secret values (ISO, sizes)
│   │   │   ├── secrets.example.pkrvars.hcl    # template for secrets (copy -> *.local)
│   │   │   └── http/
│   │   │       └── Autounattend.xml       # unattended install answer file
│   │   └── 2025/                 # Same shape as 2022
│   │
│   └── linux/                    # (stubs for future work)
│       ├── rhel/{8,9,10}/
│       ├── rocky/{8,9}/
│       └── ubuntu/{2204,2404}/
│
├── scripts/                      # Reusable provisioning, shared across versions
│   ├── windows/
│   │   ├── enable-winrm.ps1
│   │   ├── install-updates.ps1
│   │   ├── install-guest-tools.ps1
│   │   ├── cleanup.ps1
│   │   └── sysprep.ps1
│   └── linux/                    # (placeholders)
│
└── files/                        # Static files copied into images (optional)
    └── windows/
```

## Why this shape?

### Versioned, self-contained OS builds
Each `builds/<os-family>/<version>/` directory is a complete Packer build. Running
`packer build builds/windows/2022/` loads only that directory. This keeps versions
isolated — Server 2016 and 2025 can have different ISOs, disk layouts, and answer
files without interfering with each other.

### One build, many hypervisors
Inside a version directory, `*.pkr.hcl` declares a `source` per hypervisor
(`virtualbox-iso`, `qemu`, `vsphere-iso`) and a single `build` block that lists all
of them. You pick the target at runtime:

```powershell
# VirtualBox only (local dev)
packer build -only="virtualbox-iso.windows" builds/windows/2022/

# KVM only (remote)
packer build -only="qemu.windows" builds/windows/2022/

# vSphere only
packer build -only="vsphere-iso.windows" builds/windows/2022/
```

`build.ps1` wraps these commands so you don't have to remember the syntax.

### Shared provisioning
Provisioners reference `scripts/windows/*.ps1` via a relative path
(`${path.root}/../../../scripts/windows`). Fixing a script (e.g. the Windows Update
logic) fixes it for every Windows version at once.

### Secrets handling
- Non-secret values (ISO URL, checksum, disk size, CPU/RAM): committed in
  `*.auto.pkrvars.hcl`.
- Secrets (Administrator password, domain join creds, vCenter creds, license keys):
  copy `secrets.example.pkrvars.hcl` to `secrets.local.pkrvars.hcl` (gitignored) and
  pass it with `-var-file`, or supply via `PKR_VAR_*` environment variables.

## Adding a new OS version

1. Copy an existing version folder, e.g. `builds/windows/2022` → `builds/windows/2025`.
2. Update the ISO URL / checksum and any version-specific settings in
   `*.auto.pkrvars.hcl` and `http/Autounattend.xml`.
3. Build with `./build.ps1 -Os windows -Version 2025 -Hypervisor virtualbox`.

## Adding a new hypervisor to an existing version

1. Add a `required_plugins` entry and a new `source` block in the version's
   `*.pkr.hcl`.
2. Add the source's name to the `build` block's `sources = [...]` list.
3. Provide any hypervisor-specific variables.
