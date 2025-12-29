{
  config,
  lib,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    helix
    #   dolphin
    kitty
    git
    fish
    zellij
    yazi
    bottom
    eza
    vivaldi
    obsidian
    zotero
  ];
}
