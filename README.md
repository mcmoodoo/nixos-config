# Two ThinkBooks, one configuration repository

This repository uses **traditional NixOS modules, without flakes or Home Manager**.

| Computer | Entry point | Package source | State version |
| --- | --- | --- | --- |
| Original AMD ThinkBook 14 G6+ AHP (`defiance`, `mcmoodoo`) | `configuration.nix` → `hosts/old-thinkbook/configuration.nix` | Its existing NixOS 25.11 channel | `25.05` |
| Intel ThinkBook 16 G7 IML (`thinkbook16-g7`, `reed`) | `hosts/thinkbook16-g7/configuration.nix` | NixOS 26.05 snapshot in `nixpkgs.nix` | `26.05` |

**Deploy the Intel laptop using [the deployment and rollback guide](docs/thinkbook16-g7.md).**
After pulling `thinkbook16-g7`, run `bash scripts/deploy-thinkbook16-g7.sh` as `reed`
on the Intel laptop to automate backups, validation, building, desktop installation,
and next-boot preparation. It leaves rebooting to you; `--build-only` stops earlier.
Its generated hardware file is deliberately absent and gitignored. Evaluation fails
until that file is copied from the Intel laptop itself. The root-level hardware file
belongs to the encrypted AMD installation and must never be copied to the Intel host.

`modules/common/` shares services and package selections. Host modules own storage,
boot, CPU/GPU, accounts, power policy, and host-specific services. `desktop/` contains
the existing customized desktop, adapted for the pinned Intel software versions.
The desktop installer backs up files and runs only as `reed` on Intel hardware.

The development branch is `thinkbook16-g7`. Both entry points can later live on the
same mainline branch; neither machine requires switching branches for each rebuild.
No release/staging branches exist in this repository, and this migration does not
create a PR against or promote changes to a production branch.

Read [validation results and migration decisions](docs/validation.md) and
[desktop provenance](desktop/README.md). The original checkout, its uncommitted
WireGuard work, its `/etc/nixos` symlink, and its active generation are untouched.
