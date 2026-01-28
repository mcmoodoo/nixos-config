{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
    ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nixpkgs.config.allowUnfree = true;

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "kvm-amd" ];

  # boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback.out ];
  # boot.extraModprobeConfig = ''
  #   options v4l2loopback video_nr=10 card_label="iPhoneCam"
  # '';

  boot.extraModulePackages = [
      config.boot.kernelPackages.v4l2loopback.out
  ];

  # Libvirt configuration
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      runAsRoot = true;
    };
  };

  virtualisation.docker.enable = true;
  virtualisation.docker.rootless.enable = true;

  networking.hostName = "defiance";
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  networking.nameservers = ["1.1.1.1" "8.8.8.8"];

  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [8001];

  # Set your time zone.
  time.timeZone = "America/Chicago";

  i18n.defaultLocale = "en_US.UTF-8";

  services.fwupd.enable = true;

  services.displayManager.ly.enable = true;

  services.tlp.enable = true;

  services.printing.enable = true;
  services.avahi.enable = true;
  services.avahi.nssmdns4 = true;

  services.gnome.gnome-keyring.enable = true;
  # security.pam.services.hyprland.enableGnomeKeyring = true;
  security.pam.services.ly = {
    enableGnomeKeyring = true;
  };
  
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;

  services.upower.enable = true;
  services.usbmuxd.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.mcmoodoo = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "libvirtd" "kvm" "docker"];
  };

  programs.firefox.enable = true;

  environment.sessionVariables = {
    BROWSER = "brave";
  };

  # List packages installed in system profile.
  environment.systemPackages = with pkgs; [
    (yazi.override {
      _7zz = _7zz-rar;  # Support for RAR extraction
    })
    mesa-demos
    age
    tree
    pinentry-curses
    pinentry-qt
    xray
    dig
    nftables
    acpi
    awscli2
    aws-vault
    gh
    git
    gitleaks
    lazygit
    wget
    curl
    xh
    restish
    atac
    vim
    neovim
    eza
    bun
    nodejs_24
    pnpm
    libsecret
    pass
    ncdu
    unzip
    exercism
    terraform
    fastfetch
    brightnessctl
    pavucontrol
    chafa
    imagemagick
    graphviz-nox
    mermaid-cli
    nix-index
    alacritty
    ghostty
    rustup
    go
    wl-clipboard-rs
    stow
    waybar
    # swaynotificationcenter
    mako
    libnotify
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
    file
    bottom
    btop-rocm
    fd
    bat
    jq
    fx
    ripgrep
    zoxide
    w3m
    upower
    obsidian
    marktext
    typora
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
    shotcut
    # openshot-qt
    cmus
    musikcube
    clementine
    vlc
    ytmdesktop
    yt-dlp
    mpv-unwrapped
    obs-studio
    obs-studio-plugins.droidcam-obs
    linuxKernel.packages.linux_6_18.v4l2loopback
    droidcam
    ffmpeg
    chromium
    brave
    # qutebrowser
    tor-browser
    qrencode
    asciinema_3
    asciinema-agg
    krita
    inkscape
    freecad
  ];


  fonts.packages = with pkgs; [
    pkgs.nerd-fonts.hack
  ];

  programs.nix-ld.enable = true;

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

  system.autoUpgrade.enable = true;
  system.autoUpgrade.allowReboot = true;
}

