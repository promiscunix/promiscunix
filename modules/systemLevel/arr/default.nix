#
#  Media Services: Plex, Torrenting and Automation
#
{
  config,
  pkgs,
  lib,
  ...
}: {
  services = {
    jellyfin = {
      enable = true;
      openFirewall = true;
      user = "root";
      group = "root";
    };

    radarr = {
      enable = true;
      user = "damajha";
      group = "users";
      openFirewall = true;
    };
    sonarr = {
      #8989
      enable = true;
      user = "damajha";
      group = "users";
      openFirewall = true;
    };

    sabnzbd = {
      enable = true;
      user = "damajha";
      group = "users";
      openFirewall = true;
      configFile = "/var/lib/sabnzbd/sabnzbd.ini"; # optional; defaults to state dir
    };

    #    bazarr = {
    #      enable = true;
    #      user = "root";
    #      group = "users";
    #      openFirewall = true;
    #    };
    prowlarr = {
      enable = true;
      openFirewall = true;
    };
    readarr = {
      enable = true;
      user = "damajha";
      group = "users";
      openFirewall = true;
    };
    deluge = {
      enable = true;
      web.enable = true;
      user = "damajha";
      group = "users";
      openFirewall = true;
      web.openFirewall = true;
    };
    jellyseerr.enable = true;
  };
  # NOTE: this is top-level, not under `services.*`
  systemd.tmpfiles.rules = [
    "d /var/lib/sabnzbd 0775 damajha users -"
    "d /var/lib/sabnzbd/Downloads 0775 damajha users -"
    "d /var/lib/sabnzbd/Downloads/incomplete 0775 damajha users -"
    "d /var/lib/sabnzbd/Downloads/complete 0775 damajha users -"
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

