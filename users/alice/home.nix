# users/alice/home.nix
{ config, pkgs, userInfo, ... }:
{
  # home.username      = userInfo.userName;
  # home.homeDirectory = "/home/${userInfo.userName}";
  home.stateVersion  = "25.05";
  programs.home-manager.enable = true;   # gives `home-manager` CLI to Alice
  # no packages/programs yet
}
