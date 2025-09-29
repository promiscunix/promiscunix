{ config, lib, pkgs, ... }:

{
  imports =
    [ 
      ./hardware-configuration.nix
      ../../modules/core/default.nix
      ../../modules/systemLevel/networking
    ];


  system.stateVersion = "25.05"; # Did you read the comment?
}

