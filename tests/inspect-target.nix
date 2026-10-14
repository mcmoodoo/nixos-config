# Evaluate the COMPLETE target, including its locally generated hardware file.
{ nixpkgs ? import ../nixpkgs.nix }:
let
  n = import (nixpkgs + "/nixos") {
    configuration = ../hosts/thinkbook16-g7/configuration.nix;
  };
  c = n.config;
in
assert builtins.all (entry: entry.assertion) c.assertions;
{
  nixos = n.pkgs.lib.version;
  stateVersion = c.system.stateVersion;
  hostname = c.networking.hostName;
  systemDrv = n.system.drvPath;
  root = { inherit (c.fileSystems."/") device fsType options; };
  efi = { inherit (c.fileSystems."/boot") device fsType options; };
  luks = builtins.attrNames c.boot.initrd.luks.devices;
  swap = c.swapDevices;
  resumeDevice = c.boot.resumeDevice;
  user = { inherit (c.users.users.reed) home extraGroups; };
  mutableUsers = c.users.mutableUsers;
  kernel = c.boot.kernelPackages.kernel.version;
  kernelModules = c.boot.kernelModules;
  intelMicrocode = c.hardware.cpu.intel.updateMicrocode;
  graphicsPackages = map (p: p.name) c.hardware.graphics.extraPackages;
  hyprland = c.programs.hyprland.package.version;
  warnings = c.warnings;
}
