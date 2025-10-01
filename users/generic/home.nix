# This is a generic user.
# Simply copy this folder and rename it in the ./users directory of you config
# Change the info in userInfo.toml and rebuild

{ config, pkgs, userInfo, ... }:
{
  home.stateVersion  = "25.05";
  programs.home-manager.enable = true;
}
