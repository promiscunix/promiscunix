# hosts/optiplex-1/configuration.nix
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
    (mod "hyprland")

    inputs.home-manager.nixosModules.home-manager
  ];

  boot.kernelModules = [
    "coretemp"
    # add others here if sensors-detect ever suggests them
  ];

  services.dbus.enable = true; # default on NixOS unless you disabled it

  environment.systemPackages = [
    inputs.home-manager.packages.${pkgs.stdenv.hostPlatform.system}.home-manager
  ];

  system.stateVersion = "25.05";
}
