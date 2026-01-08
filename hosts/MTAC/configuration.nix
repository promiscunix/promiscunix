# hosts/MTAC/configuration.nix
{
  pkgs,
  inputs,
  lib,
  systemInfo,
  ...
}: let
  mods = ../../modules/systemLevel;
  mod = name: mods + "/${name}";
in {
  imports = [
    ./hardware-configuration.nix
    ../../modules/core
    (mod "accounts")
    (mod "arr")
    (mod "jellyfin")
    (mod "dispatcharr")
    (mod "ersatztv")
    (mod "guacamole")
    (mod "xrdp")
    (mod "nas-client")
    (mod "optimize/shared")
    (mod "optimize/optiplex")

    inputs.home-manager.nixosModules.home-manager
  ];

  boot.kernelModules = [
    "coretemp"
    # add others here if sensors-detect ever suggests them
  ];

  services.dbus.enable = true; # default on NixOS unless you disabled it

  networking.firewall.interfaces.${systemInfo.networkInterfaceName} = {
    allowedTCPPorts = [8096];
    # Jellyfin LAN discovery uses UDP 7359.
    allowedUDPPorts = [7359];
  };

  environment.systemPackages = [
    inputs.home-manager.packages.${pkgs.stdenv.hostPlatform.system}.home-manager
  ];

  system.stateVersion = "25.05";
}
