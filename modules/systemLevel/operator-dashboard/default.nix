{ config, inputs, pkgs, ... }:

{
  imports = [
    inputs.operator-dashboard.nixosModules.default
  ];

  services.operator-dashboard = {
    enable = true;
    package = inputs.operator-dashboard.packages.${pkgs.stdenv.hostPlatform.system}.operator-dashboard;
    user = "damajha";
    group = "users";
    host = "0.0.0.0";
    port = 8765;
    openFirewall = true;
    obsidianVaultPath = "/home/damajha/Documents/Obsidian Vault";
    dataDir = "/home/damajha/Documents/Obsidian Vault/04 Maps/Operator Dashboard MVP/data";
    weather = {
      location = "Maple Ridge, BC";
      latitude = 49.2193;
      longitude = -122.5984;
      timezone = "America/Vancouver";
    };
  };
}
