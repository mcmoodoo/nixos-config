# This entry point deliberately fails until the TARGET'S generated file is copied.
{ ... }:
{
  imports = [
    ./base.nix
    (if builtins.pathExists ./hardware-configuration.nix then
      ./hardware-configuration.nix
    else
      throw ''
        Missing ThinkBook 16 G7 hardware configuration.
        ON THE INTEL LAPTOP, copy /etc/nixos/hardware-configuration.nix to
        hosts/thinkbook16-g7/hardware-configuration.nix (gitignored).
        Never use the repository-root hardware-configuration.nix: it belongs to AMD.
        See docs/thinkbook16-g7.md before deploying.
      '')
  ];
}
