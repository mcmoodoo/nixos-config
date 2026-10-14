{ lib, pkgs, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nix.gc = {
    automatic = lib.mkDefault true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nixpkgs.config.allowUnfree = true;

  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/New_York";

  i18n.defaultLocale = "en_US.UTF-8";

  services.fwupd.enable = true;
  services.trezord.enable = true;
  services.displayManager.ly.enable = true;
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
    alsa.enable = true;
    wireplumber.enable = true;

  };

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;

  services.upower.enable = true;
  services.usbmuxd.enable = true;

  environment.sessionVariables = {
    BROWSER = "brave";
  };

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

}
