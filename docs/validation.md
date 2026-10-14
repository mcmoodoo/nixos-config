# Migration validation — 2026-10-14

Development took place in `/tmp/nixos-config-thinkbook16-g7`, on branch
`thinkbook16-g7`, based on original commit `384cdb3`. The original checkout is
`/home/mcmoodoo/lab/nixos-config`; `/etc/nixos` points there. Its `master` branch,
tracked file contents, uncommitted `wireguard-config.nix`, and active system link
were checked for preservation. No rebuild switch, boot installation, activation,
service restart, firmware change, or disk operation was performed on that machine.

## Results

| Check | Result |
| --- | --- |
| Nix syntax for all repository `.nix` files | Passed |
| Original host, evaluated with installed 25.11 source | Passed; before/after system derivations are identical |
| NixOS 26.05 source download and NAR hash | Passed against `nixpkgs.nix` |
| Intel base modules plus explicitly synthetic test filesystems | Passed, including all NixOS assertions and full system derivation evaluation |
| `reed`, unchanged password policy, sudo, CPU, graphics/firmware, boot permissions, firewall, services, sleep/swap checks | Passed in `tests/target-eval.nix` |
| Production entry point without target hardware file | Correctly refuses evaluation with instructions to supply the target-generated file |
| Hyprland 0.55.4 `--verify-config` | Passed: `config ok`; compositor was not started |
| Hyprlock option fields | Checked against the pinned 0.9.5 upstream parser |
| Bash syntax and ShellCheck for desktop install/restore scripts | Passed |
| Desktop JSON, TOML, and Lua syntax | Passed |
| Gitleaks secret scan of staged changes | Passed |

Old host regression: both versions evaluated to
`/nix/store/g02shldxdx5ixy16m8s6xzjv5g56xn8n-nixos-system-defiance-25.11.12484.b6018f87da91.drv`.
This proves the module extraction preserves the **committed** old configuration's
build output on its installed source. The unrelated unstaged WireGuard change was
not incorporated into the migration; it remains untouched in the original checkout.

The Intel source is NixOS `26.05.11829.a033e66ab94a`, revision
`a033e66ab94a6bedf2c3d58d93a36319d3cbbbaf`, with kernel `6.18.56`, Hyprland
`0.55.4`, Hyprlock `0.9.5`, and Hyprpaper `0.8.4`. All original common applications
evaluate on this source. Two compatibility aliases emit warnings (`xfce.thunar` and
`asciinema_3`); they are retained to preserve the old host's package selections.

## Hardware and service changes

| Original host setting | Intel host behavior |
| --- | --- |
| AMD microcode and `kvm-amd` | Intel microcode and `kvm-intel` |
| `btop-rocm` | Standard `btop` |
| Old encrypted root, EFI label, data UUID | Not imported; generated target file is mandatory |
| `linuxPackages_latest` and `v4l2loopback` | Release-default kernel, standard camera drivers; no virtual camera module |
| No explicit AMD graphics hacks were present | Standard kernel/Mesa support plus Intel media driver; no forced GPU variables |
| 32 GiB `/swapfile`, all sleep disabled | No disk swap added; 25% zram, normal suspend, no hibernation |
| TLP | Power Profiles Daemon with default policy, no speculative tuning |
| External USB microphone priority override | PipeWire automatic device selection |
| Auto-start Ollama and libvirt | Neither daemon enabled; client tools remain available |
| Docker boot service and broad `docker0` firewall exceptions | Socket activation; no copied port exceptions |
| WireGuard host identity/private-key path | No VPN import; target needs a separately provisioned identity if desired |
| User `mcmoodoo`, state version `25.05` | Existing `reed` account and credentials, state version `26.05` |

Shared printing, discovery, Trezor, audio, keyring, and desktop support remain enabled.
Avahi retains the existing mDNS use of UDP 5353. No TCP ports, SSH service, unrestricted
sudo, BIOS changes, encryption, or speculative ACPI parameters were introduced.

## Repeatable checks

On a development machine, without the target hardware file:

```bash
nix-instantiate --eval --strict --json --expr 'import ./tests/target-eval.nix {}'
bash -n scripts/install-desktop.sh scripts/restore-desktop.sh desktop/bashrc
shellcheck scripts/*.sh
git diff --check
```

`tests/target-eval.nix` uses `/dev/TEST-ONLY-DO-NOT-BOOT-*` names exclusively for
evaluation. It does not create a production hardware file or expose a deployable
system result. The actual deployment must use `tests/inspect-target.nix` and
`hosts/thinkbook16-g7/configuration.nix` after integrating real hardware.

To repeat the compositor check, fetching the pinned package without activation:

```bash
mkdir -p .validation/runtime .validation/cache
chmod 700 .validation/runtime
nixpkgs=$(nix-instantiate --eval --strict nixpkgs.nix | tr -d '"')
nix-build "$nixpkgs" -A hyprland -o .validation/hyprland
env -u WAYLAND_DISPLAY -u DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE \
  XDG_RUNTIME_DIR="$PWD/.validation/runtime" XDG_CACHE_HOME="$PWD/.validation/cache" \
  .validation/hyprland/bin/Hyprland --verify-config \
  --config "$PWD/desktop/config/hypr/hyprland.conf"
```

Nix used its download/build cache for non-activating validation; no system or user
profile was changed. Temporary sources and reports under `.validation/` are ignored.

## Still required on the Intel laptop

- Copy its generated hardware file and compare effective root/EFI devices to mounted
  devices. UUIDs were not available here and were not invented.
- Build the complete real configuration. System derivation evaluation passed here;
  the full application closure was not built/downloaded, and no target boot was tested.
- Verify Ly login, saved credentials, Intel acceleration, portals, audio, webcam,
  Bluetooth, brightness, battery readings, locking, lid handling, and suspend/resume.
- Restore user-managed toolchains/credentials and test Neovim plugins and development
  workloads. No private account state was copied or published.

The [deployment guide](thinkbook16-g7.md) includes the exact commands and rollback.
