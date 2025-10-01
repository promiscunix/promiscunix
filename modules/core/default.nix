{ config, pkgs, lib, systemInfo, userInfo, inputs, ... }:

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

}
