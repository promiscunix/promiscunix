# hosts/theLibrary/configuration.nix
{
  pkgs,
  inputs,
  lib,
  ...
}: let
  mods = ../../modules/systemLevel;
  mod = name: mods + "/${name}";
in {
  imports = [
    ./hardware-configuration.nix
    ../../modules/core
    (mod "accounts")
    (mod "nas")

    inputs.home-manager.nixosModules.home-manager
  ];


  boot.kernelModules = [
    "coretemp"
    # add others here if sensors-detect ever suggests them
  ];

  services.dbus.enable = true; # default on NixOS unless you disabled it

  # TEMPORARY RECOVERY: allow LAN SSH password login while Tailscale is down.
  # Remove this block after theLibrary is back on Tailscale and key-based SSH works.
  services.openssh.settings = {
    PasswordAuthentication = lib.mkForce true;
    KbdInteractiveAuthentication = lib.mkForce true;
  };
  networking.firewall.allowedTCPPorts = [22];

  # Required for Home Manager xdg.portal with useUserPackages
  environment.pathsToLink = [ "/share/applications" "/share/xdg-desktop-portal" ];

  environment.systemPackages = [
    inputs.home-manager.packages.${pkgs.stdenv.hostPlatform.system}.home-manager
  ];

  system.stateVersion = "25.05";
}
