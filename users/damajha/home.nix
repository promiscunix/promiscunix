# users/damajha/home.nix
{
  pkgs,
  systemInfo,
  ...
}: {
  imports = [
    ../../modules/userLevel/helix
    ../../modules/userLevel/starship
    ../../modules/userLevel/zellij
    ../../modules/userLevel/fish
  ];

  # home.username = systemInfo.mainUser;
  # home.homeDirectory = "/home/${systemInfo.mainUser}";

  home.packages = [
    pkgs.kitty.terminfo
    pkgs.bat
  ];

  home.stateVersion = "25.05";

  programs.home-manager.enable = true;
}
