#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 1 || $(id -un) != reed || $HOME != /home/reed ]] ||
   ! grep -q GenuineIntel /proc/cpuinfo; then
    printf 'Usage on the Intel laptop, as reed: %s BACKUP_DIRECTORY\n' "$0" >&2
    exit 1
fi
backup=$(realpath -- "$1")
case "$backup" in
    "$HOME"/.local/state/thinkbook16-g7/desktop-*) ;;
    *) printf 'Not a desktop backup directory.\n' >&2; exit 1 ;;
esac
[[ -f $backup/manifest && ! -e $backup/restored ]]
umask 077
mkdir -p "$backup/replaced/.config"
while IFS= read -r relative; do
    case "$relative" in
        .bashrc|.config/hypr|.config/waybar|.config/wofi|.config/mako|.config/ghostty|.config/alacritty|.config/nvim|.config/backgrounds|.config/starship.toml) ;;
        *) printf 'Unexpected backup entry: %s\n' "$relative" >&2; exit 1 ;;
    esac
    if [[ -e $HOME/$relative || -L $HOME/$relative ]]; then
        mv -- "$HOME/$relative" "$backup/replaced/$relative"
    fi
    if [[ -e $backup/original/$relative || -L $backup/original/$relative ]]; then
        mv -- "$backup/original/$relative" "$HOME/$relative"
    fi
done <"$backup/manifest"
touch "$backup/restored"
printf 'Previous desktop restored; displaced files remain under %s/replaced.\n' "$backup"
