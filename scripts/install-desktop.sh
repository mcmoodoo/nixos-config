#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if [[ ${1:-} == --dry-run ]]; then
    printf 'Will back up and install desktop/config/* into ~/.config and desktop/bashrc into ~/.bashrc.\n'
    printf 'Run without --dry-run only as reed on the Intel laptop.\n'
    exit 0
fi
if [[ $# != 0 || $(id -un) != reed || $HOME != /home/reed ]] ||
   ! grep -q GenuineIntel /proc/cpuinfo; then
    printf 'Run only as reed (without sudo) on the Intel target.\n' >&2
    exit 1
fi

umask 077
backup=$(mktemp -d "$HOME/.local/state/thinkbook16-g7/desktop-$(date +%Y%m%d-%H%M%S)-XXXXXX" 2>/dev/null) || {
    mkdir -p "$HOME/.local/state/thinkbook16-g7"
    backup=$(mktemp -d "$HOME/.local/state/thinkbook16-g7/desktop-$(date +%Y%m%d-%H%M%S)-XXXXXX")
}
mkdir -p "$backup/original/.config" "$HOME/.config" "$HOME/Pictures"
touch "$backup/manifest"
trap 'printf "Desktop backup: %s\nRestore with: %q %q\n" "$backup" "$repo/scripts/restore-desktop.sh" "$backup"' EXIT

for source in "$repo"/desktop/config/* "$repo/desktop/bashrc"; do
    if [[ $source == "$repo/desktop/bashrc" ]]; then
        relative=.bashrc
    else
        relative=.config/$(basename -- "$source")
    fi
    destination=$HOME/$relative
    if [[ -e $destination || -L $destination ]]; then
        mv -- "$destination" "$backup/original/$relative"
    fi
    printf '%s\n' "$relative" >>"$backup/manifest"
    cp -a -- "$source" "$destination"
done

# A pre-existing Lua config was backed up with the complete hypr directory.
# The pinned release therefore loads the migrated hyprland.conf consistently.
printf 'Desktop installed. Log out and back in after the NixOS deployment.\n'
