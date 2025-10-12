{
  config,
  pkgs,
  ...
}: {
  services.xserver.enable = true;
  services.xserver.desktopManager.xfce.enable = true;
  # services.desktopManager.gnome.enable = true;
  # services.xserver.displayManager.sddm.enable = true;
  # services.xserver.desktopManager.plasma6.enable = true;

  services.xrdp.enable = true;
  services.xrdp.defaultWindowManager = "startxfce4";
  services.xrdp.openFirewall = true;

  # services.xrdp = {
  #   enable               = true;
  #   # Launch Plasma on X11 when an RDP client connects:
  #   defaultWindowManager = "gnome-session";
  #   # Automatically open the RDP port (3389) in the firewall:
  #   openFirewall         = true;
  # };

  environment.systemPackages = with pkgs; [
    freerdp
  ];

  networking.firewall.allowedTCPPorts = [3389];
}
