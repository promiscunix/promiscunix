# users/damajha/home.nix
{
  lib,
  pkgs,
  systemInfo,
  ...
}: let
  profile = systemInfo.profile or "workstation";
in {
  imports =
    [
    ../../modules/userLevel/helix
    ../../modules/userLevel/starship
    ../../modules/userLevel/zellij
    ../../modules/userLevel/fish
    ../../modules/userLevel/transcode
    #   ../../modules/userLevel/tuios
    ]
    ++ lib.optionals (profile != "server") [
      ../../modules/userLevel/hyprland
    ];

  home.username = systemInfo.mainUser;
  home.homeDirectory = "/home/${systemInfo.mainUser}";
  #programs.keychain.enable = true;
  # programs.keychain.agents = ["ssh"];
  #programs.keychain.keys = ["id_ed25519"];

  home.packages = [
    pkgs.kitty.terminfo
    pkgs.bat
  ];

  home.stateVersion = "25.05";

  services.transcodeHevc.enable = systemInfo.hostName == "theLibrary";

  programs.home-manager.enable = true;
}
