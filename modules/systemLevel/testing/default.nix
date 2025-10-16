{
  config,
  lib,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    helix
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
