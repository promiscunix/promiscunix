{ config, pkgs, lib, systemInfo, ... }:

let
  inherit (lib) mkIf mkDefault;
  # Safe getters with defaults so evaluation never explodes
  hostName = systemInfo.hostName;

in  
{
 boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };
  
  # networking = {
  #   hostName = systemInfo.hostName; 
  #   networkmanager.enable = true;  
  # };
  
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

  imports = [
    ../systemLevel/networking  
  ];
  
  environment.variables = {
    PAGER = "less";
    LESS  = "-FRX";   # don't page short output; raw control chars ok
  };

  environment.shellAliases.nmcli = "PAGER=cat nmcli";

  environment.systemPackages = with pkgs; [
    helix
    git
    fish
    zellij
    yazi
    bottom
    eza
  ];

  services.openssh.enable = true;
  
  programs.ssh.startAgent = true;         # start a user ssh-agent
  programs.ssh.agentTimeout = "1h";       # optional

  

#  system.stateVersion = "25.05";
#
}
