# Deploy to the Intel ThinkBook 16 G7 IML

Run these commands **on the new Intel laptop only**, logged in as `reed`.
Do not run deployment commands on `defiance`. This procedure uses the already
installed NixOS 26.05 system; it never partitions, formats, or reinstalls it.

## Automated deployment

After cloning, the script performs steps 2–5 below, including the backups and disk
comparisons. Run on the **Intel laptop as `reed`, without sudo**:

```bash
cd ~/nixos-config
git switch thinkbook16-g7
git pull --ff-only origin thinkbook16-g7
bash scripts/deploy-thinkbook16-g7.sh
```

If Git is unavailable outside the shell used to clone, first enter `nix-shell -p git`.
The deployment script loads Git and jq in a temporary pinned Nix shell if needed.
It requests your sudo password for the privileged steps; no credentials are stored.

The script checks the username, Intel 125U CPU, Lenovo model, UEFI boot, NixOS version,
branch, clean tracked files, mounted partitions, and existing `/boot` permissions.
It preserves `/etc/nixos`, backs up the configuration under `/var/lib/thinkbook16-g7`,
and protects both the original minimal generation and this run's starting generation
against garbage collection. The latter also has a `pre-deploy-*` GC root printed in
the log. An identical host hardware file is reused; a different file is never
overwritten. The built system must match the evaluated derivation, and its Hyprland
checker must report `config ok` before home files or boot entries are changed.

Builds use at most two concurrent jobs with two cores each to limit compilation
pressure on the 16 GiB machine. Existing desktop files are backed up by the desktop
installer on each full run. The script prepares the next boot with `nixos-rebuild
boot`; it does not switch running services or reboot automatically.

Wait for **`READY TO REBOOT`**, then:

```bash
sudo reboot
```

Select Hyprland in Ly and log in as `reed`. Continue with the hardware checks in
step 6 below. If the script reports an error, do not reboot yet; retain the log at
`.validation/deploy-*/deploy.log` and the printed backup paths. The rollback section
below applies to script deployments as well as manual ones.

Optional: `bash scripts/deploy-thinkbook16-g7.sh --build-only` makes backups, imports
hardware, evaluates, builds, and checks Hyprland, then stops before desktop/boot
installation. Run without that option to finish. `--help` makes no changes.

## 1. Network, Git, and branch

```bash
whoami                         # reed
nixos-version                  # 26.05...
nmcli general status
nmcli device status
# If necessary, connect interactively without putting a Wi-Fi password in history:
nmtui

nix-shell -p git jq
git clone --branch thinkbook16-g7 https://github.com/mcmoodoo/nixos-config.git ~/nixos-config
cd ~/nixos-config
git status --short --branch
repo=$PWD
```

If already cloned, check for local work first, then use `git fetch origin` and
`git switch thinkbook16-g7` (or `git switch --track origin/thinkbook16-g7` if absent).
Do not reset or discard local edits. The repository is public; cloning needs no key.

## 2. Preserve the minimal installation

```bash
sudo install -d -m 700 /var/lib/thinkbook16-g7
backup=/var/lib/thinkbook16-g7/minimal-$(date +%Y%m%d-%H%M%S)
sudo cp -aL /etc/nixos "$backup"
printf 'Minimal configuration backup: %s\n' "$backup"

# Pin the running generation against garbage collection. Do not overwrite an
# existing minimal-system link on subsequent deployments.
sudo install -d /nix/var/nix/gcroots/thinkbook16-g7
if ! sudo test -e /nix/var/nix/gcroots/thinkbook16-g7/minimal-system; then
  sudo ln -s "$(readlink -f /run/current-system)" \
    /nix/var/nix/gcroots/thinkbook16-g7/minimal-system
fi
sudo bootctl list
sudo nix-env --profile /nix/var/nix/profiles/system --list-generations
```

Keep the previous minimal generation in the boot menu. Automatic garbage collection
is disabled on the new host during migration. No password files are copied or changed.

## 3. Integrate the actual hardware file

```bash
test -f /etc/nixos/hardware-configuration.nix
test ! -e hosts/thinkbook16-g7/hardware-configuration.nix
install -m 644 /etc/nixos/hardware-configuration.nix \
  hosts/thinkbook16-g7/hardware-configuration.nix
git check-ignore hosts/thinkbook16-g7/hardware-configuration.nix

lsblk -o NAME,SIZE,MODEL,FSTYPE,UUID,MOUNTPOINTS
findmnt /
findmnt /boot
df -h / /boot
cat hosts/thinkbook16-g7/hardware-configuration.nix
```

Expected: Samsung **256 GB / 238.5 GiB**, `/dev/nvme0n1p1` as the approximately
1 GiB FAT32 EFI partition, `/dev/nvme0n1p2` as ext4 root, no encrypted root and no
old `/mnt/data` mount. Keep the generated file intact, including its real UUIDs.
The host module preserves the proven `lib.mkForce [ "umask=0077" ]` correction;
do not edit the generated `fmask`/`dmask` entries just to duplicate that fix.

On a later deployment, the hardware file already exists: compare it to the local
`/etc/nixos/hardware-configuration.nix` rather than overwriting it blindly.

## 4. Evaluate and compare the effective filesystems

The snapshot is fixed in `nixpkgs.nix`; no channel or flake changes are needed.

```bash
nixpkgs=$(nix-instantiate --eval --strict nixpkgs.nix | tr -d '"')
mkdir -p .validation
nix-instantiate --eval --strict --json tests/inspect-target.nix --arg nixpkgs "$nixpkgs" \
  > .validation/target-inspection.json
jq . .validation/target-inspection.json

# These two comparisons must succeed. A failure means STOP and inspect the file.
test "$(readlink -f "$(jq -r .root.device .validation/target-inspection.json)")" \
  = "$(readlink -f "$(findmnt -n -o SOURCE /)")"
test "$(readlink -f "$(jq -r .efi.device .validation/target-inspection.json)")" \
  = "$(readlink -f "$(findmnt -n -o SOURCE /boot)")"
jq -e '.stateVersion == "26.05" and .root.fsType == "ext4" and
  .efi.fsType == "vfat" and .efi.options == ["umask=0077"] and
  .luks == [] and .swap == [] and .resumeDevice == "" and
  .user.home == "/home/reed" and .mutableUsers and .intelMicrocode' \
  .validation/target-inspection.json
```

The user must remain `reed` with `wheel`, `networkmanager`, and `docker` membership.
No declarative password is set; mutable users preserve existing root/user passwords.
The Docker group retains the source setup's root-equivalent Docker access. Docker
starts on socket demand; Ollama, libvirt, WireGuard, and Xray do not start on this host.

## 5. Build, install desktop files, then select the next boot

```bash
# Build only. Review available space first; the original application list is large.
nixos-rebuild build -I nixpkgs="$nixpkgs" \
  -I nixos-config="$repo/hosts/thinkbook16-g7/configuration.nix"

# Check the desktop with the BUILT compositor before installing home files.
./result/sw/bin/Hyprland --verify-config \
  --config "$repo/desktop/config/hypr/hyprland.conf"
# Require "config ok" and no configuration errors.

# Without sudo. Saves existing files and prints an exact desktop rollback command.
./scripts/install-desktop.sh

# Install the new generation for the NEXT BOOT, leaving current services running.
sudo nixos-rebuild boot -I nixpkgs="$nixpkgs" \
  -I nixos-config="$repo/hosts/thinkbook16-g7/configuration.nix"
sudo bootctl list              # confirm the previous minimal generation remains
sudo reboot
```

At Ly's login screen, select the **Hyprland** session and log in as `reed` with the
existing password. Expect the preserved desktop with Waybar, wallpaper, terminals,
launcher, notifications, audio, and Intel graphics. Display mode is detected at
scale 1; adjust `~/.config/hypr/hyprland.conf` after seeing the panel if needed.

The first build downloads the shared application set; this is the main storage/time
cost on the 256 GB SSD. There is no inherited 32 GiB swap file. Zram uses up to 25%
of RAM as compressed swap; suspend remains enabled, hibernation is disabled.

## 6. Check the new generation

```bash
systemctl --failed
systemctl --user --failed
id
findmnt -no SOURCE,FSTYPE,OPTIONS /boot
sudo stat -c '%a %U:%G %n' /boot
nmcli device status
lspci -nnk | grep -A3 -E 'VGA|Display|Network|Audio'
hyprctl configerrors
hyprctl monitors
hyprctl systeminfo
vainfo --display drm --device /dev/dri/renderD128
vulkaninfo --summary
wpctl status
bluetoothctl show
brightnessctl info
upower -e
v4l2-ctl --list-devices
systemctl --user status hyprpolkitagent
systemctl status power-profiles-daemon
journalctl -b -p err
```

The renderer should be Intel/Mesa rather than `llvmpipe`; `/boot` should be owned by
root with restrictive permissions (normally `700`). Check speakers, microphone in
`pavucontrol`, webcam in a browser, clipboard copy/paste, screenshots, launcher,
brightness and volume keys, Bluetooth, Wi-Fi reconnects, and portal screen sharing.

Test **locking and unlocking first** with Super+Shift+L. Then, with work saved, test
`systemctl suspend`, resume, lid-close behavior on battery/AC, and external monitors.
Hypridle locks at 3 minutes, blanks at 3.5 minutes, and suspends at 15 minutes.
No ACPI, fan, or Intel driver workarounds have been added. If freezes recur, retain:

```bash
journalctl --list-boots
sudo journalctl -b -1 -k > ~/previous-boot-kernel.log
sudo journalctl -b -k > ~/current-boot-kernel.log
```

Existing ACPI/firmware messages alone do not establish hardware failure. The new
journal is persistent and bounded at 512 MiB; it cannot recover logs from before
persistence was enabled or guarantee capture of an abrupt panic.

Development smoke checks:

```bash
git --version; gcc --version; python3 --version
node --version; bun --version; pnpm --version; nix --version
rustup show
docker version                # socket-activates Docker when first used
nvim                          # then :Lazy restore and :checkhealth
```

Install/transfer user-managed Rust toolchains, Foundry, optional completion scripts,
and credentials separately. The shell already uses `/home/reed` through `$HOME`.
Git author name/email intentionally preserve the existing identity; a Unix account
rename does not imply an author identity change. VPN setup requires a new peer and
its own private key; do not reuse the original machine's WireGuard identity.

## Rollback

If boot or graphical login fails, open the systemd-boot menu (hold Space during
startup) and select the previous minimal NixOS generation. If the graphical session
fails, use Ctrl+Alt+F2/F3 and log in on a TTY. The existing passwords still apply.

After booting a usable generation, restore the pinned minimal system as the default:

```bash
sudo nix-env --profile /nix/var/nix/profiles/system --set \
  /nix/var/nix/gcroots/thinkbook16-g7/minimal-system
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration boot
sudo reboot
```

NixOS generation rollback does not undo home files. Restore the desktop separately,
using the exact backup directory printed during installation:

```bash
cd ~/nixos-config
ls -d ~/.local/state/thinkbook16-g7/desktop-*
./scripts/restore-desktop.sh /home/reed/.local/state/thinkbook16-g7/desktop-TIMESTAMP-SUFFIX
```

The minimal `/etc/nixos` files were never replaced and remain an additional recovery
source; dated copies are under `/var/lib/thinkbook16-g7/`. Keep the GC root and boot
generation until the migration passes hardware checks. Do not run generation deletion
or garbage collection as part of this migration.

## Subsequent maintenance

Use the same explicit `-I nixpkgs=... -I nixos-config=...` arguments for every Intel
rebuild, recomputing `nixpkgs` from this repository. A bare rebuild still selects the
minimal `/etc/nixos` configuration. Keep the local generated file when fetching or
changing branches. Desktop updates require a separate run of the backup installer.

The original AMD host continues to use its 25.11 source and top-level entry point.
Its actual state version is **25.05**, which was deliberately preserved. Never use
the Intel source pin or Intel entry point to rebuild the original host.

References: [NixOS 26.05 manual](https://nixos.org/manual/nixos/stable/),
[Intel graphics](https://wiki.nixos.org/wiki/Intel_Graphics),
[Hyprland 0.55.4 source](https://github.com/hyprwm/Hyprland/tree/v0.55.4),
[Hyprpaper configuration](https://wiki.hypr.land/Hypr-Ecosystem/hyprpaper/).
