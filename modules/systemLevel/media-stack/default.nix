# modules/systemLevel/media-stack/default.nix
# Complete *arr media stack for theLibrary NAS
# Jellyfin exposed on all interfaces for Roku/Apple TV on LAN.
# Management apps (*arrs, SABnzbd) restricted to Tailscale.
{ config, pkgs, lib, ... }:
let
  baseDir = "/mnt/storage/media-stack";
  usenetDir = "${baseDir}/usenet";
  mediaDir  = "${baseDir}/media";
in
{
  # Shared directory tree
  systemd.tmpfiles.rules = [
    "d ${baseDir}                     0755 damajha users -"
    "d ${usenetDir}                   0755 damajha users -"
    "d ${usenetDir}/incomplete        0755 damajha users -"
    "d ${usenetDir}/complete          0755 damajha users -"
    "d ${usenetDir}/complete/movies   0755 damajha users -"
    "d ${usenetDir}/complete/tv       0755 damajha users -"
    "d ${usenetDir}/complete/books    0755 damajha users -"
    "d ${mediaDir}                    0755 damajha users -"
    "d ${mediaDir}/movies             0755 damajha users -"
    "d ${mediaDir}/tv                 0755 damajha users -"
    "d ${mediaDir}/books              0755 damajha users -"
  ];

  # --- Media Server (LAN + Tailscale) ---
  services.jellyfin = {
    enable = true;
    openFirewall = true;
    dataDir = "${baseDir}/jellyfin";
  };

  # --- Indexer Manager (Tailscale only) ---
  services.prowlarr = {
    enable = true;
    openFirewall = true;
    dataDir = "${baseDir}/prowlarr";
  };

  # --- *Arr Managers (Tailscale only) ---
  services.sonarr = {
    enable = true;
    openFirewall = true;
    dataDir = "${baseDir}/sonarr";
    user = "damajha";
    group = "users";
  };

  services.radarr = {
    enable = true;
    openFirewall = true;
    dataDir = "${baseDir}/radarr";
    user = "damajha";
    group = "users";
  };

  # Readarr is beta/prerelease — enable with caution
  services.readarr = {
    enable = true;
    openFirewall = true;
    dataDir = "${baseDir}/readarr";
    user = "damajha";
    group = "users";
  };

  services.bazarr = {
    enable = true;
    openFirewall = true;
    dataDir = "${baseDir}/bazarr";
  };

  # --- Request Manager (Tailscale only) ---
  services.seerr = {
    enable = true;
    openFirewall = true;
    configDir = "${baseDir}/seerr";
  };

  # --- Usenet Downloader (Tailscale only) ---
  services.sabnzbd = {
    enable = true;
    openFirewall = true;
    stateDir = "${baseDir}/sabnzbd";
  };

  # --- Firewall ---
  # Jellyfin already opened by openFirewall = true on all interfaces.
  # Lock management apps to Tailscale interface.
  networking.firewall.interfaces.tailscale0 = {
    allowedTCPPorts = [
      8989   # Sonarr
      7878   # Radarr
      8787   # Readarr
      9696   # Prowlarr
      6767   # Bazarr
      5055   # Seerr
      8080   # SABnzbd
    ];
  };
}
