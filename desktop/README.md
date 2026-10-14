# Preserved desktop

These files were copied read-only from the active user's `~/.config` on 2026-10-14.
Most originate in `https://github.com/mcmoodoo/dotfiles`, revision
`5bf84b112d513d3c4b79f359b2a17b0cb4682552`, with the active local customizations
included. The source dotfiles checkout was neither edited nor committed.
The two background images also already exist in that public repository.

Preserved: Dwindle layout, gaps, borders, opacity, animations, US/Russian keyboard
switching, application/workspace/resize/screenshot bindings, external mouse
preferences, Waybar layout, Catppuccin launcher/terminal themes, wallpaper and lock
screen, Alacritty, Ghostty, Mako, Starship, Bash helpers, and Neovim with its plugin
lockfile. The system package list keeps the development tools already in NixOS.

Target adaptations:

- Detect displays at their preferred resolution, scale 1. Adjust scale after seeing
  the panel; old eDP/DP/HDMI resolutions are not portable. Workspace monitor bindings
  use relative monitor selection. No AMD-specific graphics environment is set.
- Use window rules and `layoutmsg` supported by Hyprland 0.55.4. Its retained
  Hyprlang reader is used deliberately to minimize desktop changes. The install
  backs up the complete Hypr directory, including any competing `hyprland.lua`.
- Remove obsolete `dwindle:pseudotile` and `misc:vfr` settings; preserve the pseudo
  keybinding and the release's default variable frame rate behavior.
- Define the previously missing `SUPER_SHIFT` variable so lock/screenshot bindings
  work. Start Waybar, Hyprpaper, Hypridle, Mako, NetworkManager's applet, and a Polkit
  authentication agent. Ly's PAM configuration handles GNOME Keyring login.
- Translate Hyprpaper's wallpaper format and remove invalid Hyprlock options. Use
  packaged Inter fonts instead of unavailable SF Pro; install the Nerd Fonts used
  by the existing desktop. Keep the lock layout and images.
- Detect battery devices instead of assuming `BAT1`, correct Waybar's window module
  name, and remove an unused notification module that requires absent swaync.
- Omit the absent Fusuma setup and the old `rgb:kbd_backlight` idle device. Brightness
  keys, touchpad behavior, lock-before-sleep, and the 15-minute idle suspend remain.
- Change home paths to `$HOME`; make local environment/completion files optional.
  Do not carry over touchpad module-reload workarounds or force Wayland globally in
  TTY shells. Alacritty permits OSC52 copying but not applications reading the clipboard.

Install **on the target, without sudo**, with `scripts/install-desktop.sh`. It copies
editable files into `~/.config` and backs up each replaced directory/file under
`~/.local/state/thinkbook16-g7/desktop-*`. Re-run explicitly for future desktop updates;
NixOS rebuilds alone do not overwrite home files. To undo, pass the printed backup
directory to `scripts/restore-desktop.sh`; it retains the displaced files as well.

Private keys, `~/.env`, cloud/GitHub credentials, application state, browser profiles,
SSH configuration, personal completion scripts, Rust toolchains, and Foundry binaries
are not copied. Foundry was referenced by the shell but was not installed by the
original NixOS configuration. Transfer or reinstall these separately as needed.
Neovim's Lazy/Mason/Tree-sitter downloads still require network access on first use;
their runtime behavior must be checked on the target with `:checkhealth`.
