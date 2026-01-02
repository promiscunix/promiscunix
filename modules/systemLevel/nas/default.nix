# NAS Services Module
# Provides NFS exports and Syncthing for theLibrary
#
# NFS exports are restricted to Tailscale subnet (100.64.0.0/10)
# Syncthing runs as the main user with web UI on port 8384
{
  config,
  lib,
  pkgs,
  systemInfo,
  ...
}: let
  # Tailscale subnet - covers all Tailscale IPs (100.64.0.0 - 100.127.255.255)
  tailscaleSubnet = "100.64.0.0/10";

  # User mapping for NFS (all_squash)
  # Maps all remote users to local user for consistent permissions
  anonUid = 1000; # damajha
  anonGid = 100; # users

  # Common NFS export options
  nfsOpts = "rw,sync,no_subtree_check,all_squash,anonuid=${toString anonUid},anongid=${toString anonGid}";
in {
  # ============================================================================
  # NFS SERVER
  # ============================================================================

  services.nfs.server = {
    enable = true;

    # NFSv4 exports
    # Format: <path> <client>(options)
    exports = ''
      # Media exports (read-write for arr stack access)
      /mnt/storage/@media          ${tailscaleSubnet}(${nfsOpts})
      /mnt/storage/@books          ${tailscaleSubnet}(${nfsOpts})
      /mnt/storage/@downloads      ${tailscaleSubnet}(${nfsOpts})
      /mnt/storage/@documents      ${tailscaleSubnet}(${nfsOpts})

      # Backup exports (for restic/borg access from other machines)
      /mnt/critical/backups        ${tailscaleSubnet}(${nfsOpts})
    '';
  };

  # ============================================================================
  # SYNCTHING
  # ============================================================================

  services.syncthing = {
    enable = true;

    # Run as main user
    user = systemInfo.mainUser;
    group = "users";

    # Data and config directories
    dataDir = "/mnt/critical/sync/syncthing";
    configDir = "/home/${systemInfo.mainUser}/.config/syncthing";

    # Allow web UI access from Tailscale network
    guiAddress = "0.0.0.0:8384";

    # Folder configuration
    settings = {
      # Disable telemetry
      options = {
        urAccepted = -1; # Disable usage reporting
        globalAnnounceEnabled = true;
        localAnnounceEnabled = true;
        relaysEnabled = true;
      };

      # Pre-configured folders
      folders = {
        "obsidian-vault" = {
          path = "/mnt/critical/sync/syncthing/obsidian-vault";
          # Staggered versioning: keep versions for 180 days
          versioning = {
            type = "staggered";
            params = {
              cleanInterval = "3600"; # Clean up every hour
              maxAge = "15552000"; # 180 days in seconds
            };
          };
        };
      };
    };

    # Don't override manual changes to syncthing config
    overrideDevices = false;
    overrideFolders = false;
  };

  # Ensure syncthing directories exist
  systemd.tmpfiles.rules = [
    "d /mnt/critical/sync/syncthing 0750 ${systemInfo.mainUser} users -"
    "d /mnt/critical/sync/syncthing/obsidian-vault 0750 ${systemInfo.mainUser} users -"
  ];

  # ============================================================================
  # FIREWALL
  # ============================================================================

  networking.firewall = {
    # Allow NFS only on Tailscale interface
    interfaces.tailscale0 = {
      allowedTCPPorts = [
        2049 # NFS
        111 # portmapper/rpcbind
      ];
      allowedUDPPorts = [
        2049 # NFS
        111 # portmapper/rpcbind
      ];
    };

    # Syncthing ports (allow on all interfaces for discovery)
    allowedTCPPorts = [
      8384 # Syncthing Web UI
      22000 # Syncthing sync protocol
    ];
    allowedUDPPorts = [
      22000 # Syncthing sync protocol
      21027 # Syncthing discovery
    ];
  };

  # ============================================================================
  # DEPENDENCIES
  # ============================================================================

  # Ensure rpcbind is enabled (required for NFS)
  services.rpcbind.enable = true;
}
