{ config, pkgs, lib, systemInfo, userInfo, inputs, ... }:

# let
#   inherit (lib) mkIf mkDefault;
#   # Safe getters with defaults so evaluation never explodes
#   #  hostName = systemInfo.hostName;

# in  
{
  imports = [
    ../systemLevel/networking  
    ../systemLevel/testing
  ];

 boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };
    
  boot.supportedFilesystems = [ "btrfs" ];

  nixpkgs.config.allowUnfree = true;

  security.sudo.wheelNeedsPassword = false;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  programs.fish.enable = true;
  
  users.users.${systemInfo.mainUser} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = lib.mkDefault pkgs.fish;
  };

  
  environment.shellAliases.nmcli = "PAGER=cat nmcli";

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false; 
      PermitRootLogin = "no";
    };
  };
  
  programs.ssh.startAgent = true;         # start a user ssh-agent
  programs.ssh.agentTimeout = "1h";       # optional

  

#  system.stateVersion = "25.05";
#
}
