{ config, pkgs, ... }:
{
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  environment.systemPackages = [
    pkgs.rofi
    pkgs.dunst
    pkgs.libnotify
    pkgs.awww
    pkgs.networkmanagerapplet
    pkgs.pyprland
    pkgs.hyprcursor
    pkgs.wayvnc
    pkgs.bash
  ];

  environment.sessionVariables = {
  	WLR_NO_HARDWARE_CURSORS = "1";
  	NIXOS_OZONE_WL = "1";
  };

  hardware = {
  	graphics.enable = true;
  	nvidia.modesetting.enable = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [5900];
  
 #  home.file.".config/hypr/pyprland.toml".source = ./pyprland.toml;
}
