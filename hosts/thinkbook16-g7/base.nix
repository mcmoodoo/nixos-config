# Lenovo ThinkBook 16 G7 IML, Core Ultra 5 125U, 16 GiB RAM, 256 GB NVMe.
# Filesystems and storage drivers come exclusively from the target-generated file.
{ config, lib, pkgs, ... }:
{
  imports = [ ../../modules/common ];

  networking.hostName = "thinkbook16-g7";
  networking.firewall.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Retain old boot entries for rollback on the 1 GiB ESP.
  boot.loader.systemd-boot.configurationLimit = 10;
  # Required: replace the generated fmask/dmask=0022, preserving its device UUID.
  fileSystems."/boot".options = lib.mkForce [ "umask=0077" ];

  # Use the release's default kernel, its Intel DRM driver, and Mesa.
  # Do not carry over AMD modules, ROCm, force_probe, or graphics environment hacks.
  boot.kernelModules = [ "kvm-intel" ];
  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
  hardware.graphics = {
    enable = true;
    extraPackages = [ pkgs.intel-media-driver ];
  };
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  services.power-profiles-daemon.enable = true;
  # Normal suspend/lid defaults remain enabled. No disk swap or resume device is added.
  zramSwap.enable = true;
  zramSwap.memoryPercent = 25;
  systemd.sleep.settings.Sleep = {
    AllowHibernation = false;
    AllowHybridSleep = false;
    AllowSuspendThenHibernate = false;
  };

  # Preserve evidence if the reported post-firmware boot freeze recurs.
  services.journald.extraConfig = ''
    Storage=persistent
    SystemMaxUse=512M
  '';
  # Keep the minimal installation's fallback until migration is accepted.
  nix.gc.automatic = false;

  # Python 3.11's optional HTML docs fail in Sphinx/Docutils on this pin.
  # Keep Python and man/info pages; remove this workaround once upstream is fixed.
  # https://github.com/NixOS/nixpkgs/issues/499166
  documentation.doc.enable = false;

  users.mutableUsers = true;
  users.users.reed = {
    isNormalUser = true;
    home = "/home/reed";
    extraGroups = [ "wheel" "networkmanager" "docker" ];
    # No password fields: preserve the existing account's /etc/shadow entry.
  };

  # Available on demand; no Ollama server, libvirt daemon, VPN, or open-port rules.
  virtualisation.docker = {
    enable = true;
    package = pkgs.docker_29;
    enableOnBoot = false;
  };

  security.rtkit.enable = true;
  programs.hyprlock.enable = true;
  services.gvfs.enable = true;
  # Started by the compositor after it imports its Wayland/D-Bus environment.
  systemd.user.services.hyprpolkitagent = {
    description = "Hyprland authentication agent";
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  environment.systemPackages = (import ../../modules/common/packages.nix { inherit pkgs; })
    ++ (with pkgs; [
      networkmanagerapplet
      playerctl
      wf-recorder
      libva-utils
      pciutils
      usbutils
      vulkan-tools
      alsa-utils
      v4l-utils
    ]);
  fonts.packages = with pkgs; [
    nerd-fonts.caskaydia-cove
    nerd-fonts.jetbrains-mono
    inter
  ];

  assertions = [
    {
      assertion = lib.versions.majorMinor lib.version == "26.05";
      message = "Build the Intel host with the pinned NixOS 26.05 source (see nixpkgs.nix).";
    }
    {
      assertion = config.fileSystems."/".fsType == "ext4"
        && config.fileSystems."/boot".fsType == "vfat";
      message = "Preserve the target's ext4 root and FAT32 EFI filesystems.";
    }
    {
      assertion = config.boot.initrd.luks.devices == { }
        && !(builtins.elem "kvm-amd" config.boot.kernelModules)
        && !config.hardware.cpu.amd.updateMicrocode;
      message = "The target must not import the original AMD laptop's encrypted-disk or CPU configuration.";
    }
  ];

  system.stateVersion = "26.05";
}
