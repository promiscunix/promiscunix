{
  pkgs,
  inputs,
  lib,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/core/default.nix
    ../../modules/systemLevel/accounts
    ../../modules/systemLevel/dispatcharr
    inputs.home-manager.nixosModules.home-manager
  ];

  services.dbus.enable = true;

  services.dispatcharr = {
    enable = true;
    dataDir = "/var/lib/dispatcharr";
    port = 9191;
    backend = "docker"; # or "podman" if you prefer
    openFirewall = true;
  };

  environment.systemPackages = [
    inputs.home-manager.packages.${pkgs.system}.home-manager
  ];

  boot.kernelModules = [
    "coretemp"
  ];

  system.stateVersion = "25.05";
}


