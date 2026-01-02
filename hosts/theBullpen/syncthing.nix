# Syncthing configuration for theBullpen
#
# Syncs Obsidian vault with theLibrary NAS
#
# AFTER DEPLOYMENT - Complete setup via web UI (http://localhost:8384):
#
# 1. Get theLibrary's Device ID:
#    - SSH to theLibrary: ssh damajha@100.82.217.116
#    - Run: syncthing cli show system | grep myID
#    - Or check theLibrary's web UI at http://100.82.217.116:8384
#
# 2. Add theLibrary as a remote device:
#    - Go to: Actions > Show ID (to get theBullpen's ID)
#    - Then: Add Remote Device > paste theLibrary's Device ID
#    - Name it "theLibrary"
#
# 3. On theLibrary's web UI (http://100.82.217.116:8384):
#    - Add theBullpen as a remote device using its ID
#    - Share the "promiscunix" folder with theBullpen
#
# 4. Accept the folder share on theBullpen when prompted
#
{
  config,
  lib,
  pkgs,
  ...
}: {
  services.syncthing = {
    enable = true;

    # Run as main user
    user = "damajha";
    group = "users";

    # Data and config directories
    dataDir = "/home/damajha/.local/share/syncthing";
    configDir = "/home/damajha/.config/syncthing";

    # Web UI accessible from Tailscale network
    guiAddress = "0.0.0.0:8384";

    # Folder configuration
    settings = {
      # Disable telemetry
      options = {
        urAccepted = -1;
        globalAnnounceEnabled = true;
        localAnnounceEnabled = true;
        relaysEnabled = true;
      };

      # Pre-configured folders
      folders = {
        "promiscunix" = {
          path = "/home/damajha/vaults/promiscunix";
          # Staggered versioning: keep versions for 180 days
          versioning = {
            type = "staggered";
            params = {
              cleanInterval = "3600";     # Clean up every hour
              maxAge = "15552000";        # 180 days in seconds
            };
          };
          # Devices will be added via web UI
          # After adding theLibrary device, it will appear here
        };
      };
    };

    # Don't override manual changes (device additions, etc.)
    overrideDevices = false;
    overrideFolders = false;
  };

  # Ensure directories exist
  systemd.tmpfiles.rules = [
    "d /home/damajha/.local/share/syncthing 0750 damajha users -"
    "d /home/damajha/.config/syncthing 0750 damajha users -"
    "d /home/damajha/vaults 0750 damajha users -"
    "d /home/damajha/vaults/promiscunix 0750 damajha users -"
  ];

  # Firewall rules for Syncthing
  networking.firewall = {
    allowedTCPPorts = [
      8384   # Web UI
      22000  # Sync protocol
    ];
    allowedUDPPorts = [
      22000  # Sync protocol
      21027  # Discovery
    ];
  };
}
