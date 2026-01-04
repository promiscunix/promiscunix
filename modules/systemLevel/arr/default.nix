#
#  Arr Stack: Torrenting and Automation
#
{
  config,
  pkgs,
  lib,
  systemInfo,
  ...
}: let
  mainUser = systemInfo.mainUser;
in {
  services = {
    radarr = {
      enable = true;
      user = mainUser;
      group = "users";
    };
    sonarr = {
      #8989
      enable = true;
      user = mainUser;
      group = "users";
    };

    sabnzbd = {
      enable = true;
      user = mainUser;
      group = "users";
      configFile = "/var/lib/sabnzbd/sabnzbd.ini"; # optional; defaults to state dir
    };

    #    bazarr = {
    #      enable = true;
    #      user = "root";
    #      group = "users";
    #    };
    prowlarr = {
      enable = true;
    };
    readarr = {
      enable = true;
      user = mainUser;
      group = "users";
    };
    deluge = {
      enable = true;
      web.enable = true;
      user = mainUser;
      group = "users";
    };
    jellyseerr.enable = true;
  };

  # Patch SABnzbd config to bind to all interfaces and allow Tailscale network
  systemd.services.sabnzbd.preStart = lib.mkAfter ''
    if [ -f /var/lib/sabnzbd/sabnzbd.ini ]; then
      ${pkgs.gnused}/bin/sed -i 's/^host = 127.0.0.1/host = 0.0.0.0/' /var/lib/sabnzbd/sabnzbd.ini
      ${pkgs.gnused}/bin/sed -i 's/^local_ranges = ,$/local_ranges = 100.64.0.0\/10,/' /var/lib/sabnzbd/sabnzbd.ini
    fi
  '';

  # NOTE: this is top-level, not under `services.*`
  systemd.tmpfiles.rules = [
    "d /var/lib/sabnzbd 0775 ${mainUser} users -"
    "d /var/lib/sabnzbd/Downloads 0775 ${mainUser} users -"
    "d /var/lib/sabnzbd/Downloads/incomplete 0775 ${mainUser} users -"
    "d /var/lib/sabnzbd/Downloads/complete 0775 ${mainUser} users -"
  ];

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    7878 # radarr
    8989 # sonarr
    8080 # sabnzbd
    9696 # prowlarr
    8787 # readarr
    8112 # deluge web
    58846 # deluge daemon
    5055 # jellyseerr
  ];
}
# literally can't be bothered anymore with user permissions.
# So everything with root, add permissions 775 with group users in radarr and sonarr
# (Under Media Management - Show Advanced | Under Subtitles)
# Radarr & Sonarr: chmod 775
# Bazarr: chmod 664
# Prowlarr should just work
# Deluge:
#   Connection Manager: localhost:58846
#   Preferences: Change download folder and enable Plugins-label
