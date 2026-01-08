# NAS Client Module
# Mounts NFS shares from theLibrary (NAS server) for media access
#
# Used by MTAC for Jellyfin and arr stack to access media files
{
  config,
  lib,
  pkgs,
  ...
}: let
  # theLibrary's LAN IP
  nasServer = "192.168.0.152";

  # Common NFS mount options
  nfsOpts = ["nfsvers=4" "hard" "timeo=600" "retrans=2" "_netdev" "x-systemd.automount" "x-systemd.idle-timeout=600"];
in {
  # Enable NFS client support
  services.rpcbind.enable = true;
  boot.supportedFilesystems = ["nfs"];

  # Mount points for NAS shares
  fileSystems = {
    # Media library (movies, TV, music, etc.)
    "/mnt/nas/media" = {
      device = "${nasServer}:/mnt/storage/@media";
      fsType = "nfs";
      options = nfsOpts;
    };

    # Books (ebooks, audiobooks, magazines)
    "/mnt/nas/books" = {
      device = "${nasServer}:/mnt/storage/@books";
      fsType = "nfs";
      options = nfsOpts;
    };

    # Downloads (for arr stack)
    "/mnt/nas/downloads" = {
      device = "${nasServer}:/mnt/storage/@downloads";
      fsType = "nfs";
      options = nfsOpts;
    };

    # Documents
    "/mnt/nas/documents" = {
      device = "${nasServer}:/mnt/storage/@documents";
      fsType = "nfs";
      options = nfsOpts;
    };
  };

  # Ensure mount point directories exist
  systemd.tmpfiles.rules = [
    "d /mnt/nas 0755 root root -"
    "d /mnt/nas/media 0755 root root -"
    "d /mnt/nas/books 0755 root root -"
    "d /mnt/nas/downloads 0755 root root -"
    "d /mnt/nas/documents 0755 root root -"
  ];
}
