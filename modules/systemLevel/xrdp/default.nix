{
  config,
  pkgs,
  lib,
  ...
}: {
  # Enable X11 (required for xrdp - Wayland not supported)
  services.xserver.enable = true;

  # Plasma 6 desktop environment
  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = false; # xrdp requires X11
  };

  # xrdp configuration
  services.xrdp = {
    enable = true;
    defaultWindowManager = "startplasma-x11";
    openFirewall = true;
    # Customize xrdp.ini for better performance
    extraConfDirCommands = ''
      # Enable high color depth and performance settings
      ${pkgs.gnused}/bin/sed -i 's/^max_bpp=.*/max_bpp=24/' $out/xrdp.ini
      ${pkgs.gnused}/bin/sed -i 's/^#\?bitmap_cache=.*/bitmap_cache=true/' $out/xrdp.ini
      ${pkgs.gnused}/bin/sed -i 's/^#\?bitmap_compression=.*/bitmap_compression=true/' $out/xrdp.ini
      ${pkgs.gnused}/bin/sed -i 's/^#\?bulk_compression=.*/bulk_compression=true/' $out/xrdp.ini
    '';
  };

  # RDP client tools
  environment.systemPackages = with pkgs; [
    freerdp # RDP client for testing
  ];
}
