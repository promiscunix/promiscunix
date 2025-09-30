{ config, pkgs, ... }:

{
  # Required:
  home.username = "damajha";
  home.homeDirectory = "/home/damajha";

  # Set once, then leave it. Use the HM release you’re on (e.g. "25.05").
  # Check with: home-manager --version
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;
}
