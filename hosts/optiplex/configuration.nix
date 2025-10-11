# hosts/optiplex/configuration.nix
{
  config,
  lib,
  pkgs,
  inputs,
  systemInfo,
  userInfo,
  userInfos,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/core/default.nix
    ../../modules/systemLevel/accounts
    inputs.home-manager.nixosModules.home-manager
  ];

  environment.systemPackages = [
    inputs.home-manager.packages.${pkgs.system}.home-manager
  ];

  system.stateVersion = "25.05";
}
