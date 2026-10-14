#!/usr/bin/env bash
# Run on the Intel laptop as reed. Sourcing defines helpers without deploying.
set -Eeuo pipefail

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Usage: bash scripts/deploy-thinkbook16-g7.sh [--build-only]

Run as reed, without sudo, on the Intel ThinkBook 16 G7 IML.
Default: back up, import hardware, validate, build, install desktop files, and
prepare the next NixOS boot. You will be asked for your sudo password as needed.
The script never reboots or switches the running system.

--build-only  Stop after building and checking Hyprland. No desktop installation
              or boot preparation; backups and the local hardware copy are made.
--help        Show this help without changing anything.
EOF
}

validate_identity() {
    local username=$1 home_directory=$2 architecture=$3 version=$4 cpu=$5 dmi=$6 uefi=$7
    [[ $username == reed && $home_directory == /home/reed ]] ||
        die 'Run as reed with home /home/reed, without sudo.'
    [[ $architecture == x86_64 && $version == 26.05* ]] ||
        die 'This installer requires the existing x86_64 NixOS 26.05 installation.'
    [[ $cpu == *GenuineIntel* && $cpu == *125U* ]] ||
        die 'This installer is only for the Intel Core Ultra 5 125U target.'
    dmi=${dmi,,}
    dmi=${dmi//[[:space:]]/}
    [[ $dmi == *lenovo* && $dmi == *thinkbook16g7iml* && $uefi == yes ]] ||
        die 'Expected a Lenovo ThinkBook 16 G7 IML booted in UEFI mode.'
}

check_host() {
    local cpu dmi uefi=no
    cpu=$(cat /proc/cpuinfo)
    dmi=$(cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name \
        /sys/class/dmi/id/product_version)
    [[ ! -d /sys/firmware/efi ]] || uefi=yes
    validate_identity "$(id -un)" "$HOME" "$(uname -m)" "$(nixos-version)" "$cpu" "$dmi" "$uefi"
}

check_checkout() {
    local repository=$1
    [[ $(git -C "$repository" branch --show-current) == thinkbook16-g7 ]] ||
        die 'Check out the thinkbook16-g7 branch before running this script.'
    if ! git -C "$repository" diff --quiet || ! git -C "$repository" diff --cached --quiet; then
        die 'Tracked files have local changes. Preserve and review them before deploying.'
    fi
}

resolve_device() {
    local device=$1
    case "$device" in
        UUID=*|LABEL=*|PARTUUID=*|PARTLABEL=*) device=$(findfs "$device") ;;
    esac
    readlink -e -- "$device"
}

check_storage() {
    local permissions owner boot_options
    mounted_root=$(resolve_device "$(findmnt -nro SOURCE --mountpoint /)")
    mounted_boot=$(resolve_device "$(findmnt -nro SOURCE --mountpoint /boot)")
    [[ $mounted_root == /dev/nvme0n1p2 && -b $mounted_root &&
       $mounted_boot == /dev/nvme0n1p1 && -b $mounted_boot ]] ||
        die 'Mounted root/EFI partitions differ from the reported nvme0n1p2/nvme0n1p1 installation.'
    [[ $(findmnt -nro FSTYPE --mountpoint /) == ext4 &&
       $(findmnt -nro FSTYPE --mountpoint /boot) == vfat ]] ||
        die 'Expected an ext4 root and a separately mounted FAT32 /boot.'
    permissions=$(stat -c '%a' /boot)
    owner=$(stat -c '%u' /boot)
    if [[ $owner != 0 ]] || (( (8#$permissions & 077) != 0 )); then
        die '/boot must already be owned by root with no group/other access.'
    fi
    boot_options=$(findmnt -nro OPTIONS --mountpoint /boot)
    [[ ,$boot_options, == *,rw,* ]] || die '/boot must be mounted read/write.'
    lsblk -o NAME,SIZE,MODEL,FSTYPE,UUID,MOUNTPOINTS /dev/nvme0n1
    df -h / /boot
}

pin_fallback() {
    local running_system=$1 link=$2
    if sudo test -e "$link" || sudo test -L "$link"; then
        if ! sudo test -L "$link" || ! sudo test -x "$link/bin/switch-to-configuration"; then
            die "Existing fallback is invalid; leaving it untouched: $link"
        fi
    else
        sudo ln -s -- "$running_system" "$link"
    fi
}

backup_installation() {
    local config_directory=$1 running_system=$2 backup_root=$3 gc_roots=$4
    [[ -f $config_directory/configuration.nix && -f $config_directory/hardware-configuration.nix ]] ||
        die 'The existing NixOS configuration and generated hardware file are required.'
    [[ -x $running_system/bin/switch-to-configuration ]] || die 'Cannot locate the running NixOS generation.'
    sudo install -d -m 700 "$backup_root"
    system_backup=$(sudo mktemp -d "$backup_root/pre-deploy-$(date +%Y%m%d-%H%M%S)-XXXXXX")
    sudo cp -aL -- "$config_directory" "$system_backup/nixos"
    sudo ln -s -- "$running_system" "$system_backup/running-system"
    sudo install -d "$gc_roots"
    pin_fallback "$running_system" "$gc_roots/minimal-system"
    # Retain this run's starting generation as well, including on later deployments.
    fallback_root=$gc_roots/$(basename -- "$system_backup")
    pin_fallback "$running_system" "$fallback_root"
    printf 'System configuration backup: %s\nFallback generation: %s\n' "$system_backup" "$fallback_root"
}

import_hardware() {
    local source=$1 destination=$2
    [[ -f $source ]] || die "Missing target-generated hardware file: $source"
    [[ ! -L $destination ]] || die "Hardware destination is a symlink; leaving it untouched: $destination"
    if [[ -e $destination ]]; then
        cmp -s -- "$source" "$destination" ||
            die "Hardware files differ. Leaving both untouched: $source and $destination"
        printf 'Reusing the identical target-generated hardware file.\n'
    else
        install -m 644 -- "$source" "$destination"
    fi
}

validate_inspection() {
    local inspection=$1 root_device=$2 boot_device=$3 configured_root configured_boot
    jq -e '
      .stateVersion == "26.05" and .hostname == "thinkbook16-g7" and
      .root.fsType == "ext4" and .efi.fsType == "vfat" and
      .efi.options == ["umask=0077"] and .luks == [] and .swap == [] and
      .resumeDevice == "" and .user.home == "/home/reed" and
      (.user.extraGroups | index("wheel") != null) and
      (.user.extraGroups | index("networkmanager") != null) and
      .mutableUsers == true and .intelMicrocode == true
    ' "$inspection" >/dev/null || die 'The evaluated configuration failed the target safety checks.'
    configured_root=$(resolve_device "$(jq -er .root.device "$inspection")")
    configured_boot=$(resolve_device "$(jq -er .efi.device "$inspection")")
    [[ $configured_root == "$root_device" && $configured_boot == "$boot_device" ]] ||
        die 'Configured root/EFI devices do not match the currently mounted partitions.'
}

verify_desktop() {
    local system=$1 config=$2 directory=$3
    mkdir -p "$directory/runtime" "$directory/cache"
    chmod 700 "$directory/runtime"
    # Check only; do not connect to an existing compositor or start a new one.
    env -u WAYLAND_DISPLAY -u DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE \
        XDG_RUNTIME_DIR="$directory/runtime" XDG_CACHE_HOME="$directory/cache" \
        "$system/sw/bin/Hyprland" --verify-config --config "$config" \
        >"$directory/hyprland-check.log" 2>&1
    cat "$directory/hyprland-check.log"
    # Some versions can report configuration errors with a successful exit status.
    grep -qx 'config ok' "$directory/hyprland-check.log" || die 'Hyprland did not report config ok.'
    if grep -qi 'config error' "$directory/hyprland-check.log"; then
        die 'Hyprland reported configuration errors.'
    fi
}

on_error() {
    local status=$1 line=$2
    trap - ERR EXIT
    printf '\nStopped during %s (line %s, exit %s).\n' "${deploy_stage:-preflight}" "$line" "$status" >&2
    [[ -z ${run_directory:-} ]] || printf 'Log: %s/deploy.log\n' "$run_directory" >&2
    [[ -z ${system_backup:-} ]] || printf 'Configuration backup: %s\n' "$system_backup" >&2
    [[ -z ${fallback_root:-} ]] || printf 'Fallback generation: %s\n' "$fallback_root" >&2
    printf 'Do not reboot after an error. See docs/thinkbook16-g7.md for recovery.\n' >&2
    exit "$status"
}

main() {
    local build_only=false repository script pin bootstrap command revision built_system
    case ${1:-} in
        --help|-h) usage; return ;;
        --build-only) build_only=true; shift ;;
        '') ;;
        *) usage >&2; die "Unknown option: $1" ;;
    esac
    [[ $# == 0 ]] || die 'Unexpected arguments.'
    # These checks precede ALL writes, sudo calls, downloads, and dependency setup.
    deploy_stage='host checks'
    check_host
    script=$(readlink -e -- "${BASH_SOURCE[0]}")
    repository=$(cd -- "$(dirname -- "$script")/.." && pwd -P)
    cd -- "$repository"

    deploy_stage='loading the pinned NixOS source'
    pin=$(nix-instantiate --eval --strict "$repository/nixpkgs.nix" | tr -d '"')
    [[ $pin == /nix/store/* && -f $pin/nixos/default.nix ]] || die 'Invalid pinned NixOS source path.'
    if ! command -v git >/dev/null || ! command -v jq >/dev/null; then
        [[ ${THINKBOOK_DEPLOY_BOOTSTRAPPED:-0} != 1 ]] || die 'Git/jq are still unavailable in the temporary Nix shell.'
        printf 'Loading Git and jq in a temporary shell; no profile is changed.\n'
        printf -v bootstrap '%q ' bash "$script"
        [[ $build_only == false ]] || bootstrap+='--build-only'
        export THINKBOOK_DEPLOY_BOOTSTRAPPED=1
        exec nix-shell -I "nixpkgs=$pin" -p git jq --run "$bootstrap"
    fi
    for command in sudo nixos-rebuild nix-store findmnt findfs lsblk stat flock bootctl; do
        command -v "$command" >/dev/null || die "Required command is unavailable: $command"
    done
    check_checkout "$repository"
    revision=$(git rev-parse HEAD)

    umask 077
    mkdir -p "$repository/.validation"
    exec 9>"$repository/.validation/deploy.lock"
    flock -n 9 || die 'Another deployment is already running from this checkout.'
    run_directory=$(mktemp -d "$repository/.validation/deploy-$(date +%Y%m%d-%H%M%S)-XXXXXX")
    exec > >(tee -a "$run_directory/deploy.log") 2>&1
    printf 'Deploying commit %s\nLog: %s/deploy.log\n' "$revision" "$run_directory"

    deploy_stage='checking mounted storage'
    check_storage
    sudo -v
    deploy_stage='backing up the current installation'
    backup_installation /etc/nixos "$(readlink -e /run/current-system)" \
        /var/lib/thinkbook16-g7 /nix/var/nix/gcroots/thinkbook16-g7
    sudo bootctl --no-pager list

    deploy_stage='importing target hardware'
    import_hardware /etc/nixos/hardware-configuration.nix \
        "$repository/hosts/thinkbook16-g7/hardware-configuration.nix"
    cp -- "$repository/hosts/thinkbook16-g7/hardware-configuration.nix" "$run_directory/hardware-configuration.nix"

    deploy_stage='evaluating the complete target configuration'
    nix-instantiate --eval --strict --json "$repository/tests/inspect-target.nix" \
        --arg nixpkgs "$pin" >"$run_directory/inspection.json"
    validate_inspection "$run_directory/inspection.json" "$mounted_root" "$mounted_boot"
    jq . "$run_directory/inspection.json"

    deploy_stage='building the target (this can take a while)'
    # Do not allow an inherited NIXOS_CONFIG to override the explicit target path.
    (cd -- "$run_directory" && env -u NIXOS_CONFIG nixos-rebuild build --no-flake --max-jobs 2 --cores 2 \
        -I "nixpkgs=$pin" -I "nixos-config=$repository/hosts/thinkbook16-g7/configuration.nix")
    built_system=$(readlink -e "$run_directory/result")
    [[ $built_system == /nix/store/* && -x $built_system/bin/switch-to-configuration ]] ||
        die 'The build did not produce a NixOS system.'
    [[ $(nix-store -q --deriver "$built_system") == "$(jq -er .systemDrv "$run_directory/inspection.json")" ]] ||
        die 'The build differs from the evaluated configuration; leaving the boot configuration untouched.'
    deploy_stage='checking the built desktop'
    verify_desktop "$built_system" "$repository/desktop/config/hypr/hyprland.conf" "$run_directory"
    if [[ $build_only == true ]]; then
        printf '\nBUILD CHECK PASSED. Desktop files and boot configuration were not changed.\n'
        printf 'Run this script without --build-only to finish deployment.\n'
        return
    fi

    # Detect changes made while a long build was running before installing anything.
    check_checkout "$repository"
    [[ $(git rev-parse HEAD) == "$revision" ]] || die 'The checkout changed during the build; rerun the script.'
    cmp -s "$run_directory/hardware-configuration.nix" \
        "$repository/hosts/thinkbook16-g7/hardware-configuration.nix" || die 'Hardware configuration changed during the build.'
    deploy_stage='installing the desktop with backups'
    bash "$repository/scripts/install-desktop.sh"
    deploy_stage='preparing the next boot'
    sudo env -u NIXOS_CONFIG nixos-rebuild boot --no-flake --max-jobs 2 --cores 2 \
        -I "nixpkgs=$pin" -I "nixos-config=$repository/hosts/thinkbook16-g7/configuration.nix"
    [[ $(readlink -e /nix/var/nix/profiles/system) == "$built_system" ]] ||
        die 'The selected system profile differs from the checked build.'
    sudo bootctl --no-pager list
    touch "$run_directory/READY-TO-REBOOT"
    printf '\nREADY TO REBOOT. Run: sudo reboot\n'
    printf 'Then select Hyprland in Ly and log in as reed with your existing password.\n'
    printf 'If startup fails, select the previous generation in systemd-boot (hold Space).\n'
    printf 'Backup: %s\nFallback: %s\nLog: %s/deploy.log\n' "$system_backup" "$fallback_root" "$run_directory"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    trap 'on_error "$?" "$LINENO"' ERR
    trap 'status=$?; if (( status != 0 )); then on_error "$status" "$LINENO"; fi' EXIT
    main "$@"
fi
