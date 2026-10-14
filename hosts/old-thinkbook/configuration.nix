# Original Lenovo ThinkBook 14 G6+ AHP. Keep its existing disks and services.
{ config, pkgs, ... }:
{
  imports = [
    ../../modules/common
    ../../hardware-configuration.nix
    ../../wireguard-config.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "v4l2loopback" ];
  boot.extraModulePackages = [
    config.boot.kernelPackages.v4l2loopback.out
  ];

  # 32 GiB swap file (NixOS creates and manages it; no partition resize needed)
  swapDevices = [
    {
      device = "/swapfile";
      size = 32 * 1024; # size in MiB
    }
  ];

  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      runAsRoot = true;
    };
  };

  virtualisation.docker.enable = true;
  virtualisation.docker.package = pkgs.docker_29;

  networking.hostName = "defiance";
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

  services.tlp.enable = true;

  services.pipewire = {
    # Make the USB mic the default capture source (beat onboard pro-input @2500).
    wireplumber.extraConfig."51-usb-mic-priority" = {
      "monitor.alsa.rules" = [
        {
          matches = [
            { "node.name" = "~alsa_input.usb-Generic_USB2.0_Device.*"; }
          ];
          actions.update-props = {
            "priority.session" = 3000;
          };
        }
      ];
    };
  };

  systemd.sleep.extraConfig = ''
    AllowSuspend=no
    AllowHibernation=no
    AllowHybridSleep=no
    AllowSuspendThenHibernate=no
  '';

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

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.mcmoodoo = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "libvirtd" "kvm" "docker"];
  };

  environment.systemPackages = import ../../modules/common/packages.nix {
    inherit pkgs;
    monitorPackage = pkgs.btop-rocm;
  };

  system.stateVersion = "25.05";
}
