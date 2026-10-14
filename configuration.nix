# The traditional /etc/nixos entry point continues to select the original laptop.
# The Intel laptop uses hosts/thinkbook16-g7/configuration.nix explicitly.
{ ... }:
{
  imports = [ ./hosts/old-thinkbook/configuration.nix ];
}
