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
    firefox # independent browser for WebRTC/microphone diagnosis
    obsidian
    zotero
  ];
}
