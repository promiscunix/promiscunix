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
    ../../modules/systemLevel/samba
    ../../modules/systemLevel/guacamole
    ../../modules/systemLevel/xrdp
    inputs.home-manager.nixosModules.home-manager
  ];

  boot.kernelModules = [
    "coretemp"
    # add others here if sensors-detect ever suggests them
  ];

  environment.systemPackages = [
    inputs.home-manager.packages.${pkgs.system}.home-manager
    pkgs.samba
  ];

  system.stateVersion = "25.05";
}
