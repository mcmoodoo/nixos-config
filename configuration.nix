{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      # ./xray-config.nix
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

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "v4l2loopback" ];
  boot.extraModulePackages = [
    config.boot.kernelPackages.v4l2loopback.out
  ];

  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      runAsRoot = true;
    };
  };

  virtualisation.docker.enable = true;

  networking.hostName = "defiance";
  networking.networkmanager.enable = true;

  networking.nameservers = ["1.1.1.1" "8.8.8.8"];

  networking.firewall = {
    enable = true;

    interfaces.docker0 = {
      allowedTCPPorts = [ 3000 ];

      allowedTCPPortRanges = [
        { from = 10000; to = 65535; }
      ];

      allowedUDPPortRanges = [
        { from = 10000; to = 65535; }
      ];
    };
  };

  # Set your time zone.
  time.timeZone = "America/Chicago";

  i18n.defaultLocale = "en_US.UTF-8";

  services.fwupd.enable = true;
  services.displayManager.ly.enable = true;
  services.tlp.enable = true;
  services.printing.enable = true;
  services.gnome.gnome-keyring.enable = true;
  # security.pam.services.hyprland.enableGnomeKeyring = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };

  security.pam.services.ly = {
    enableGnomeKeyring = true;
  };
  
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  systemd.services.tun2socks =
    let
      tunName = "tun0";
      tunAddr = "10.0.0.1/24";
      socksProxy = "socks5://127.0.0.1:1080";
    in
    {
      description = "Transparent proxy via tun2socks";
      after = [ "network.target" ];
      wantedBy = [ ];

      serviceConfig = {
        Type = "simple";
        ExecStartPre = [
          "-${pkgs.iproute2}/bin/ip tuntap add mode tun dev ${tunName}"
          "-${pkgs.iproute2}/bin/ip addr add ${tunAddr} dev ${tunName}"
          "${pkgs.iproute2}/bin/ip link set ${tunName} up"
        ];

        ExecStart = ''
          ${pkgs.tun2socks}/bin/tun2socks \
            -device ${tunName} \
            -proxy ${socksProxy}
        '';

        ExecStartPost = [
          "${pkgs.iproute2}/bin/ip route add 0.0.0.0/1 dev ${tunName}"
          "${pkgs.iproute2}/bin/ip route add 128.0.0.0/1 dev ${tunName}"
        ];

        ExecStopPost = [
          "-${pkgs.iproute2}/bin/ip route del 0.0.0.0/1 dev ${tunName}"
          "-${pkgs.iproute2}/bin/ip route del 128.0.0.0/1 dev ${tunName}"
          "-${pkgs.iproute2}/bin/ip link set ${tunName} down"
          "-${pkgs.iproute2}/bin/ip tuntap del mode tun dev ${tunName}"
        ];

        Restart = "on-failure";
      };
    };

  systemd.services.ollama = {
    description = "Ollama Local Server";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.ollama}/bin/ollama serve";
      Restart = "always";
      RestartSec = 5;
      User = "mcmoodoo";
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
    wantedBy = [ "multi-user.target" ];
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

  environment.sessionVariables = {
    BROWSER = "brave";
  };

  environment.systemPackages = with pkgs; [
    (yazi.override {
      _7zz = _7zz-rar;
    })
    sqlite
    sqlitebrowser
    postgresql
    dbeaver-bin
    age
    tree
    pinentry-curses
    pinentry-qt
    tun2socks
    sniffnet
    dig
    nftables
    acpi
    s3fs
    rclone
    ollama
    goofys
    awscli2
    gh
    lazygit
    lazydocker
    lazyjournal
    gitleaks
    trufflehog
    detect-secrets
    shellcheck
    semgrep
    clamav
    rsync
    aria2
    wget
    curl
    xh
    tcpdump
    restish
    atac
    superfile
    nnn
    vifm
    vim
    neovim
    eza
    bun
    nodejs_24
    pnpm
    libsecret
    openssl
    pass
    ncdu
    libzip
    unzip
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
    libisoburn
    virt-manager
    libguestfs
    xfce.thunar
    wofi
    starship
    gcc
    gnumake
    lua
    luarocks-nix
    rustup
    python311
    uv
    lld
    ydiff
    diff-so-fancy
    delta
    broot
    fzf
    file
    bottom
    btop-rocm
    fd
    bat
    html-tidy
    envsubst
    yq-go
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
    firejail
    just
    resvg
    zettlr
    zoom-us
    discord
    slack
    telegram-desktop
    qbittorrent-enhanced
    blueman
    shotcut
    # openshot-qt
    cmus
    kew
    termusic
    ytermusic
    musikcube
    clementine
    vlc
    ytmdesktop
    yt-dlp
    mpv-unwrapped
    obs-studio
    obs-studio-plugins.droidcam-obs
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

  system.stateVersion = "25.05";
}

