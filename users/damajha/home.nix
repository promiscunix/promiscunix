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
    ../../modules/userLevel/tuios
  ];

  # home.username = systemInfo.mainUser;
  # home.homeDirectory = "/home/${systemInfo.mainUser}";
  programs.keychain.enable = true;
  # programs.keychain.agents = ["ssh"];
  programs.keychain.keys = ["id_ed25519"];

  home.packages = [
    pkgs.kitty.terminfo
    pkgs.bat
  ];

  home.stateVersion = "25.05";

  programs.home-manager.enable = true;
}
