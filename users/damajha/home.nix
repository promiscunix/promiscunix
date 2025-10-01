{ config, pkgs, systemInfo, userInfo, ... }:

{
  # Required:
  home.username = systemInfo.mainUser;
  home.homeDirectory = "/home/${systemInfo.mainUser}";

  home.packages = [
    pkgs.bat
  ];
  
  # Set once, then leave it. Use the HM release you’re on (e.g. "25.05").
  # Check with: home-manager --version
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;
}
