# hosts/theBullpen/configuration.nix
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
    ./syncthing.nix
    ../../modules/core
    (mod "accounts")
    (mod "hyprland")
    (mod "hermes")
    (mod "audio")
    (mod "creator-tools")
    (mod "network-tools")
    (mod "virtualization-tools")
    (mod "pangolin-newt")
    (mod "cockpit")
    (mod "web-terminal")
    (mod "browser-search")
    (mod "nas-client")
    (mod "operator-dashboard")
    (mod "bullpen-workbench")
    (mod "obscura-research")
    (mod "optimize/shared")
    (mod "optimize/optiplex")

    inputs.home-manager.nixosModules.home-manager
  ];

  promiscunix.tailscale.bootstrapSsh = true;
  promiscunix.tailscale.acceptDns = false;

  boot.kernelModules = [
    "coretemp"
    # add others here if sensors-detect ever suggests them
  ];

  services.dbus.enable = true; # default on NixOS unless you disabled it

  # Host desktop only — do not install this in the disposable Workbench container.
  programs.kdeconnect.enable = true;

  # KDE Connect discovery/pairing. Restrict it to the physical LAN, never
  # Tailscale or a public-facing interface.
  networking.firewall.interfaces.${systemInfo.networkInterfaceName} = {
    allowedTCPPortRanges = [{
      from = 1714;
      to = 1764;
    }];
    allowedUDPPortRanges = [{
      from = 1714;
      to = 1764;
    }];
  };

  # Required for Home Manager xdg.portal with useUserPackages
  environment.pathsToLink = ["/share/applications" "/share/xdg-desktop-portal"];

  environment.systemPackages = [
    inputs.home-manager.packages.${pkgs.stdenv.hostPlatform.system}.home-manager
  ];

  system.stateVersion = "25.05";
}
