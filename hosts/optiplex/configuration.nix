# hosts/optiplex/configuration.nix
{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/core/default.nix
    ../../modules/systemLevel/accounts
    inputs.home-manager.nixosModules.home-manager
  ];

  boot.kernelModules = [
    "coretemp"
    # add others here if sensors-detect ever suggests them
  ];

  environment.systemPackages = [
    inputs.home-manager.packages.${pkgs.system}.home-manager
  ];

  system.stateVersion = "25.05";
}
