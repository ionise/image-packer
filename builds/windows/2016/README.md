# Windows Server 2016 (stub)

This version is not yet implemented. To scaffold it:

1. Copy `builds/windows/2022` to `builds/windows/2016`.
2. Rename the `*.pkr.hcl` / `*.pkrvars.hcl` files to `windows-2016*`.
3. Update the `build` block `name` to `windows-2016`.
4. Set the 2016 ISO URL/checksum in the `*.auto.pkrvars.hcl`.
5. Set `<Value>Windows Server 2016 SERVERSTANDARD</Value>` in `http/Autounattend.xml`
   (confirm the exact image name with `dism /Get-WimInfo`).

See [docs/structure.md](../../../docs/structure.md) for guidance.
