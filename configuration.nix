{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  nixpkgs.config.allowUnfree = true;

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "kvm-amd" ];

  virtualisation.libvirtd.enable = true;

  networking.hostName = "defiance";
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "America/Chicago";

  i18n.defaultLocale = "en_US.UTF-8";

  services.fwupd.enable = true;

  services.displayManager.ly.enable = true;

  services.tlp.enable = true;

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.hyprland.enableGnomeKeyring = true;
  
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;

  services.upower.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.mcmoodoo = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "libvirtd" "kvm" ];
  };

  programs.firefox.enable = true;

  # environment.sessionVariables = {
  #   BRAVE_PASSWORD_STORE = "basic";
  # };

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    (yazi.override {
      _7zz = _7zz-rar;  # Support for RAR extraction
    })
    age
    tree
    pinentry-curses
    pinentry-qt
    dig
    acpi
    awscli2
    gh
    git
    gitleaks
    lazygit
    wget
    curl
    restish
    vim
    neovim
    eza
    bun
    nodejs_24
    libsecret
    pass
    ncdu
    unzip
    terraform
    fastfetch
    brightnessctl
    pavucontrol
    chafa
    imagemagick
    graphviz-nox
    nix-index
    alacritty
    ghostty
    rustup
    wl-clipboard-rs
    stow
    waybar
    mako
    hyprlock
    hyprpaper
    hyprshot
    hypridle
    qemu
    libvirt
    virt-manager
    xfce.thunar
    wofi
    starship
    gcc
    gnumake
   # readline
    lua
    luarocks-nix
    python311
    uv
    lld
    ydiff
    broot
    fzf
    bottom
    btop-rocm
    fd
    bat
    jq
    ripgrep
    zoxide
    w3m
    upower
    marktext
    foliate
    evince
    zathura
    zellij
    just
    imagemagick
    resvg
    zettlr
    zoom-us
    discord
    telegram-desktop
    qbittorrent-enhanced
    blueman
    mpv-unwrapped
    ffmpeg
    brave
  ];

  fonts.packages = with pkgs; [
    pkgs.nerd-fonts.hack
  ];

  # Some programs need SUID wrappers, can be configured further or are started in user sessions.
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  programs.git = {
    enable = true;
    config = {
      user.name = "mcmoodoo";
      user.email = "rashid@mcmoodoo.com";
    };
  };  

  # system.copySystemConfiguration = true;

  system.stateVersion = "25.05";

}

