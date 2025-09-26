{ config, lib, pkgs, ... }:

{
  imports =
    [ 
      ./hardware-configuration.nix
    ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };
  
  networking = {
    hostName = "optiplex"; 
    networkmanager.enable = true;  
  };
  
  boot.supportedFilesystems = [ "btrfs" ];

  nixpkgs.config.allowUnfree = true;

  security.sudo.wheelNeedsPassword = false;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  users.users.damajha = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    packages = with pkgs; [
    ];
  };

  environment.systemPackages = with pkgs; [
    helix
    git
    fish
    zellij
    yazi
  ];

  services.openssh.enable = true;

  system.stateVersion = "25.05"; # Did you read the comment?
}

