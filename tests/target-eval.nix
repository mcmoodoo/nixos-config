# Evaluation ONLY. The fake device names cannot represent a deployable system.
# Production always imports hosts/thinkbook16-g7/configuration.nix instead.
{ nixpkgs ? import ../nixpkgs.nix }:
let
  evaluated = import (nixpkgs + "/nixos") {
    configuration = {
      imports = [ ../hosts/thinkbook16-g7/base.nix ];
      nixpkgs.hostPlatform = "x86_64-linux";
      fileSystems."/" = {
        device = "/dev/TEST-ONLY-DO-NOT-BOOT-root";
        fsType = "ext4";
      };
      fileSystems."/boot" = {
        device = "/dev/TEST-ONLY-DO-NOT-BOOT-efi";
        fsType = "vfat";
        options = [ "fmask=0022" "dmask=0022" ];
      };
    };
  };
  c = evaluated.config;
  lib = evaluated.pkgs.lib;
in
assert c.system.stateVersion == "26.05";
assert c.users.users.reed.home == "/home/reed";
assert c.users.mutableUsers;
assert c.users.users.reed.hashedPassword == null;
assert c.users.users.reed.hashedPasswordFile == null;
assert c.users.users.reed.password == null;
assert c.users.users.reed.initialPassword == null;
assert c.users.users.reed.initialHashedPassword == null;
assert c.security.sudo.wheelNeedsPassword;
assert !(c.users.users ? mcmoodoo);
assert c.fileSystems."/boot".options == [ "umask=0077" ];
assert c.boot.loader.systemd-boot.enable;
assert c.hardware.cpu.intel.updateMicrocode;
assert !c.hardware.cpu.amd.updateMicrocode;
assert c.hardware.graphics.enable;
assert c.hardware.enableRedistributableFirmware;
assert !c.services.tlp.enable;
assert c.services.power-profiles-daemon.enable;
assert !(c.systemd.services ? ollama);
assert !c.virtualisation.libvirtd.enable;
assert !c.virtualisation.docker.enableOnBoot;
assert c.networking.wireguard.interfaces == { };
assert c.networking.firewall.enable;
assert c.networking.firewall.allowedTCPPorts == [ ];
assert !c.services.openssh.enable;
assert !c.nix.gc.automatic;
assert !c.documentation.doc.enable;
assert c.documentation.man.enable && c.documentation.info.enable;
assert c.swapDevices == [ ];
assert c.boot.resumeDevice == "";
assert c.systemd.sleep.settings.Sleep.AllowSuspend or true;
assert c.programs.hyprland.enable && c.programs.hyprlock.enable;
assert c.services.pipewire.enable && c.xdg.portal.enable;
assert builtins.all (entry: entry.assertion) c.assertions;
{
  fixtureOnly = true;
  nixos = lib.version;
  hyprland = c.programs.hyprland.package.version;
  kernel = c.boot.kernelPackages.kernel.version;
  systemDrv = evaluated.system.drvPath;
  python = evaluated.pkgs.python311.outPath;
  pythonDocDrv = evaluated.pkgs.python311.doc.drvPath;
  packageNames = map (p: p.name) c.environment.systemPackages;
  bootOptions = c.fileSystems."/boot".options;
  warnings = c.warnings;
}
